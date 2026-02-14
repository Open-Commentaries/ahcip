defmodule Kodon.WorkRegistry do
  @moduledoc """
  Central registry of known works and their metadata.

  Each work entry describes how to find, parse, and route a CTS text.
  """

  @type section_type :: :book | :hymn

  @type tei_format :: :book_card_milestone | :line_elements

  @type work :: %{
          urn: String.t(),
          slug: String.t(),
          title: String.t(),
          section_label: String.t(),
          section_type: section_type(),
          tei_format: tei_format(),
          tei_path: String.t(),
          sections: [integer()],
          has_scholar_translations: boolean()
        }

  @hymn_titles %{
    1 => "To Dionysus",
    2 => "To Demeter",
    3 => "To Apollo",
    4 => "To Hermes",
    5 => "To Aphrodite",
    6 => "To Aphrodite",
    7 => "To Dionysus",
    8 => "To Ares",
    9 => "To Artemis",
    10 => "To Aphrodite",
    11 => "To Athena",
    12 => "To Hera",
    13 => "To Demeter",
    14 => "To the Mother of the Gods",
    15 => "To Heracles the Lion-hearted",
    16 => "To Asclepius",
    17 => "To the Dioscuri",
    18 => "To Hermes",
    19 => "To Pan",
    20 => "To Hephaestus",
    21 => "To Apollo",
    22 => "To Poseidon",
    23 => "To the Son of Cronos, Most High",
    24 => "To Hestia",
    25 => "To the Muses and Apollo",
    26 => "To Dionysus",
    27 => "To Artemis",
    28 => "To Athena",
    29 => "To Hestia",
    30 => "To Earth the Mother of All",
    31 => "To Helios",
    32 => "To Selene",
    33 => "To the Dioscuri"
  }

  @doc """
  Returns the list of all known works.
  """
  @spec works() :: [work()]
  def works do
    [iliad(), odyssey()] ++ hymns()
  end

  @doc """
  Returns the Iliad work entry.
  """
  def iliad do
    %{
      urn: "urn:cts:greekLit:tlg0012.tlg001",
      slug: "tlg0012.tlg001",
      title: "The Iliad",
      section_label: "Scroll",
      section_type: :book,
      tei_format: :book_card_milestone,
      tei_path: "tlg0012/tlg001/tlg0012.tlg001.perseus-eng4.xml",
      sections: Enum.to_list(1..24),
      has_scholar_translations: true
    }
  end

  @doc """
  Returns the Odyssey work entry.
  """
  def odyssey do
    %{
      urn: "urn:cts:greekLit:tlg0012.tlg002",
      slug: "tlg0012.tlg002",
      title: "The Odyssey",
      section_label: "Scroll",
      section_type: :book,
      tei_format: :book_card_milestone,
      tei_path: "tlg0012/tlg002/tlg0012.tlg002.perseus-eng4.xml",
      sections: Enum.to_list(1..24),
      has_scholar_translations: false
    }
  end

  @doc """
  Returns work entries for all 33 Homeric Hymns.
  """
  def hymns do
    for n <- 1..33 do
      padded = String.pad_leading(Integer.to_string(n), 3, "0")

      %{
        urn: "urn:cts:greekLit:tlg0013.tlg#{padded}",
        slug: "tlg0013.tlg#{padded}",
        title: Map.get(@hymn_titles, n, "Hymn #{n}"),
        section_label: "Hymn",
        section_type: :hymn,
        tei_format: :line_elements,
        tei_path: "tlg0013/tlg#{padded}/tlg0013.tlg#{padded}.perseus-eng2.xml",
        sections: [1],
        has_scholar_translations: false
      }
    end
  end

  @doc """
  Look up a work by its slug.
  """
  @spec find_by_slug(String.t()) :: work() | nil
  def find_by_slug(slug) do
    Enum.find(works(), &(&1.slug == slug))
  end

  @doc """
  Get the fallback hymn title for a given hymn number.
  """
  def hymn_title(n), do: Map.get(@hymn_titles, n, "Hymn #{n}")
end
