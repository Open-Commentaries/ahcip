defmodule Kodon.CommentExtractor do
  @moduledoc """
  Extracts scholarly commentary from a PostgreSQL text-format dump file.

  Parses the COPY blocks for the relevant tables, filters to the homer
  project (id=1), selects the newest revision per comment, and outputs JSON.
  """

  @homer_project_id "1"

  @tables %{
    comment: "public.alexandria_app_comment",
    comment_commenters: "public.alexandria_app_comment_commenters",
    customuser: "public.alexandria_app_customuser",
    revisionbase: "public.alexandria_app_revisionbase",
    revisioncomment: "public.alexandria_app_revisioncomment"
  }

  @comment_columns [
    :id,
    :urn,
    :privacy,
    :project_id,
    :comment_citation_urn,
    :featured,
    :updated_at
  ]
  @comment_commenters_columns [:id, :comment_id, :customuser_id]
  @customuser_columns [
    :id,
    :password,
    :last_login,
    :is_superuser,
    :username,
    :first_name,
    :last_name,
    :email,
    :is_staff,
    :is_active,
    :date_joined,
    :picture,
    :bio,
    :tagline,
    :full_name
  ]
  @revisionbase_columns [:id, :text, :text_raw, :title, :created_at, :updated_at]
  @revisioncomment_columns [:revisionbase_ptr_id, :comment_id]

  @doc """
  Extracts comments from the given pg_dump file and writes JSON to output_path.
  Returns the number of comments extracted.
  """
  def extract(dump_path, output_path) do
    raw = File.read!(dump_path)

    # Parse all relevant tables
    comments = extract_table(raw, @tables.comment, @comment_columns)

    comment_commenters =
      extract_table(raw, @tables.comment_commenters, @comment_commenters_columns)

    users = extract_table(raw, @tables.customuser, @customuser_columns)
    revisionbases = extract_table(raw, @tables.revisionbase, @revisionbase_columns)
    revisioncomments = extract_table(raw, @tables.revisioncomment, @revisioncomment_columns)

    # Filter to homer project
    homer_comments =
      comments
      |> Enum.filter(&(&1.project_id == @homer_project_id))

    # Build lookup maps
    user_map = Map.new(users, &{&1.id, &1})
    revisionbase_map = Map.new(revisionbases, &{&1.id, &1})

    # Group comment_commenters by comment_id
    commenters_by_comment =
      comment_commenters
      |> Enum.group_by(& &1.comment_id)

    # Group revisioncomments by comment_id
    revisions_by_comment =
      revisioncomments
      |> Enum.group_by(& &1.comment_id)

    # Build output entries
    entries =
      homer_comments
      |> Enum.map(fn comment ->
        build_entry(
          comment,
          revisions_by_comment,
          revisionbase_map,
          commenters_by_comment,
          user_map
        )
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&{&1.work, &1.book, &1.start_line})

    # Write JSON
    File.mkdir_p!(Path.dirname(output_path))
    json = JSON.encode!(entries)
    File.write!(output_path, json)

    length(entries)
  end

  defp build_entry(
         comment,
         revisions_by_comment,
         revisionbase_map,
         commenters_by_comment,
         user_map
       ) do
    # Find newest revision for this comment
    revision =
      case Map.get(revisions_by_comment, comment.id) do
        nil ->
          nil

        rev_links ->
          rev_links
          |> Enum.map(fn rc -> Map.get(revisionbase_map, rc.revisionbase_ptr_id) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.max_by(& &1.created_at, fn -> nil end)
      end

    case revision do
      nil ->
        nil

      rev ->
        # Get authors
        authors =
          case Map.get(commenters_by_comment, comment.id) do
            nil ->
              []

            links ->
              links
              |> Enum.map(fn cc ->
                case Map.get(user_map, cc.customuser_id) do
                  nil -> nil
                  user -> author_name(user)
                end
              end)
              |> Enum.reject(&is_nil/1)
              |> Enum.reject(&(&1 == ""))
          end

        # Parse the URN
        urn_info = parse_urn(comment.urn)

        # Parse Draft.js content
        content = parse_draftjs(rev.text)

        Map.merge(urn_info, %{
          urn: comment.urn,
          citation_urn: null_to_nil(comment.comment_citation_urn) || "",
          content: content,
          title: null_to_nil(rev.title),
          authors: authors,
          created_at: format_timestamp(rev.created_at),
          updated_at: format_timestamp(rev.updated_at)
        })
    end
  end

  defp author_name(user) do
    case null_to_nil(user.full_name) do
      nil ->
        first = null_to_nil(user.first_name) || ""
        last = null_to_nil(user.last_name) || ""
        String.trim("#{first} #{last}")

      name ->
        name
    end
  end

  @doc """
  Parses a CTS URN like `urn:cts:greekLit:tlg0012.tlg001:1.5-1.10` or
  `urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1.5` into a map with
  :work, :book, :start_line, :end_line.
  """
  def parse_urn(urn) do
    # Extract work identifier and passage
    # tlg0012 = Homer (tlg001 = Iliad, tlg002 = Odyssey)
    # tlg0013 = Homeric Hymns (tlg001-tlg033)
    case Regex.run(~r/(tlg\d+)\.(tlg\d+)(?:\.[^:]+)?:(.+)$/, urn) do
      [_, "tlg0012", work_id, passage] ->
        work = if work_id == "tlg001", do: "iliad", else: "odyssey"
        {book, start_line, end_line} = parse_passage(passage)
        %{work: work, book: book, start_line: start_line, end_line: end_line}

      [_, "tlg0013", hymn_id, passage] ->
        # Homeric Hymns: hymn number from the tlg suffix
        hymn_num = hymn_id |> String.replace_leading("tlg", "") |> String.to_integer()
        {_book, start_line, end_line} = parse_passage(passage)
        %{work: "hymn", book: hymn_num, start_line: start_line, end_line: end_line}

      _ ->
        %{work: nil, book: nil, start_line: nil, end_line: nil}
    end
  end

  defp parse_passage(passage) do
    # Remove any sub-word references (e.g., @word)
    clean = String.replace(passage, ~r/@[^-]*/, "")

    case String.split(clean, "-") do
      [single] ->
        {book, line} = parse_book_line(single)
        {book, line, line}

      [start_ref, end_ref] ->
        {book, start_line} = parse_book_line(start_ref)
        {_end_book, end_line} = parse_book_line(end_ref)
        {book, start_line, end_line}
    end
  end

  defp parse_book_line(ref) do
    case String.split(ref, ".") do
      [book_str, line_str] ->
        {parse_int(book_str), parse_int(line_str)}

      [book_str] ->
        {parse_int(book_str), nil}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_draftjs(text) do
    case null_to_nil(text) do
      nil ->
        nil

      str ->
        case JSON.decode(str) do
          {:ok, decoded} -> decoded
          {:error, _} -> %{"raw" => str}
        end
    end
  end

  defp format_timestamp(ts) do
    case null_to_nil(ts) do
      nil ->
        nil

      str ->
        # Normalize pg timestamp formats to ISO 8601
        # Input: "2021-06-04 20:16:30.114+00" or "2021-06-04 20:16:30.587071+00"
        str
        |> String.replace(~r/\+00$/, "Z")
        |> String.replace(" ", "T")
    end
  end

  # --- Table extraction ---

  defp extract_table(raw, table_name, columns) do
    # Find the COPY header line and extract the data until "\."
    copy_header = "COPY #{table_name} ("

    case :binary.match(raw, copy_header) do
      {start, _len} ->
        # Find the end of the header line (the "FROM stdin;\n")
        header_end = find_newline(raw, start)
        # Find the terminator "\.\n"
        data_section = binary_part(raw, header_end + 1, byte_size(raw) - header_end - 1)
        data_end = find_copy_end(data_section)
        data = binary_part(data_section, 0, data_end)

        data
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn line -> parse_row(line, columns) end)

      :nomatch ->
        []
    end
  end

  defp find_newline(binary, offset) do
    case :binary.match(binary, "\n", scope: {offset, byte_size(binary) - offset}) do
      {pos, _} -> pos
      :nomatch -> byte_size(binary)
    end
  end

  defp find_copy_end(data) do
    case :binary.match(data, "\n\\.") do
      {pos, _} -> pos
      :nomatch -> byte_size(data)
    end
  end

  defp parse_row(line, columns) do
    values = split_tabs(line)

    columns
    |> Enum.zip(values)
    |> Map.new()
  end

  # Split on tabs, but handle the case where there are fewer values than columns
  defp split_tabs(line) do
    String.split(line, "\t")
  end

  defp null_to_nil("\\N"), do: nil
  defp null_to_nil(""), do: nil
  defp null_to_nil(val), do: val
end
