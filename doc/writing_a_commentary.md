# Writing a Commentary

Commentaries can be written across any number of files, as long as they are in the `commentaries` directory.
Each file ending with `.md` in that directory will be read and transformed into one or more comments or glosses on the critical text.

## Required metadata

Every file in the `commentaries` directory **must** begin with a short [YAML](https://yaml.org) header. It should look something like this (the comments are not necessary):

```
---
# the URN of your commentary --- this can be repeated across commentary files. Your commentary
# should be identified by a unique string in the `version` fragment of the CTS URN --- `ahcip`
# in this example.
urn: "urn:cts:greekLit:tlg0012.tlg001.ahcip"

# the base URN to which this commentary file points. Citations for individual comments will be appended to this URN.
# The `target_urn` should point to a specific edition ("version" in CTS URN-speak) of the critical text.
target_urn: "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2"

# A list of one or more authors of the comments contained in this file. The `username` field will be used
# to link comments to an author across files in the `commentaries` directory, so it should be the same for
# a given author across the project.
authors:
    - name: "Author First"
      email: "author@first.com"
      username: "author1"
    - name: "Author Second"
      email: "author@second.com"
      username: "author2"
---
```

## Writing the comments

We borrow the syntax that [Remark](https://github.com/gnab/remark/wiki/Markdown#slide-properties) uses for delimiting slides:
every comment should be separated by three hyphen characters with one or more newlines on either side:

```
---
```

After the separator, you can add citation information:

```markdown
---

target_citation: 1.1@μῆνιν
```

This citation information will be appended to the `target_urn` that you set in the YAML header, yielding, in this case, `urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1.1@μῆνιν`.
This means that you must use a fully resolved citation without abbreviations. E.g., `target_citation: 1.1-5` is invalid: the parser might just fail, or it might interpret it
as saying, "This comment covers everything from _Iliad_ 1.1 to the end of Book 5." Instead, to add a comment on lines 1 through 5 in Book 1, you would write,
`target_citation: 1.1-1.5`.

Note that `target_citation` can also be used to refer to this comment by appending it to the commentary's URN: `urn:cts:greekLit:tlg0012.tlg001.ahcip:1.1@μῆνιν`. In this
second case, we're overloading what the citation fragment means in CTS URN terms. To get around this issue, you could also supply your own unique string as a `citation`:

```markdown
---

target_citation: 1.1@μῆνιν
citation: citation-1
```

You can also include an `authors` property, listing the usernames (separated by commas) of authors who have worked specifically on this comment.

```markdown
---

target_citation: 1.1@μῆνιν
citation: citation-1
authors: gnagy, lmuellner, lslatkin
```

Each comment should also have a title, but it can be an empty string if you don't want a title rendered for this comment. So a full example might look something like this:

```markdown
---

target_citation: 1.1@μῆνιν
citation: citation-1

# My title

This is a comment on the first word of the _Iliad_.
```

## Comment content

The content of each comment can be valid markdown. You can reference images and other multimedia by storing them alongside the commentary files in the `commentaries` directory,
or you can include full URLs to request them from external resources.
