Encoding a New Translation
------

A block (a line of poetry, a paragraph or section of prose) in a translation for "Commentaries in Progress" need two basic components:

1. An identifier, usually the line, paragraph, or section number/letter. For alignment to work, this identifier should correspond to the identifier in the target critical edition.
2. Textual content, i.e., the actual words of the line, paragraph, or section.

The basic syntax will resemble [Pandoc's markdown](https://pandoc.org/MANUAL.html#pandocs-markdown), but we need to add a few elements to support these identifiers.

But first, we'll need a bit of metadata.

## Metadata and configuration

At the top of each translation file, you will need to define a few parameters as a [YAML metadata block](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block). For example, for Book 1 of the _Iliad_:

```yaml
---
title: The Homeric Iliad
description:
    Note that the YAML syntax is very persnickety. Make
    sure that any multiline descriptions are indented
    at the same level on each line.
translators:
    - Casey Dué
    - Mary Ebbott
    - Douglas Frame
    - Leonard Muellner
    - Gregory Nagy
# Note that the book identifier is included in the URN -- for
# Iliad 2, you would write "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:2"
# In general, you should specify up to the second-deepest level of citation in the work. For the Homeric epics, that means specifying up to the book; for the Homeric Hymns, that means specifying the hymn (which, perhaps confusingly, occurs in the CTS URN work fragment).
target_urn: "urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1"
urn: "urn:cts:greekLit:tlg0012.tlg001.ahcip:1"
# optional: specify the separator for identifier segments
# defaults to a period (`.`)
separator: "."
---
```

## Textual content

Immediately following the metadata, the text should begin. Any text between the metadata block and the first identifier _should_ be ignored, but it might cause the application to behave unexpectedly.

### Identifiers

Identifiers should be enclosed in square brackets (`[]`) followed by a space. Each segment of each identifier should be separated by the identifier that you specified in the metadata block. (By default, the separator is a period (`.`), which you don't need to specify.)

In order to form the full citation for an identifier, each identifier will be appended (preceded by the specifier) to the `urn` and `target_urn` that you have specified in the metadata.

For example, for the following line

```
[1] The anger [me>nis] of Peleus' son Achilles, goddess, perform its song --
```

the complete `target_urn` will be formed by appending `1` to the base `target_urn`, giving us

```
urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1.1
```

For the Homeric Hymn to Demeter (`urn:cts:greekLit:tlg0013.tlg002.perseus-grc2`), because the Homeric Hymns have a line-based cite structure (and are identified as different `work`s by their CTS URNs), the location would be appended directly to the URN:

```
urn:cts:greekLit:tlg0013.tlg002.perseus-grc2:1
```

### Textual content

The textual content can contain valid markdown. The order of the text matters. If you wish to indicate a line transposition in your edition, for example, you might have the following:

```
[79] This line's identifier suggests it comes after the following line
[78] But because textual order matters, we will preserve the ordering given in your translation
```

 Notes should be encoded as inline footnotes. E.g., instead of

```
[13] to get his daughter's release, bringing with him a ransom [apoina] beyond telling, [n:=I-1.372]
```

write

```
[13] to get his daughter's release, bringing with him a ransom [apoina] beyond telling,^[=I-1.372]
```

(Ideally, we would also change the citation to the full CTS URN: `urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1.372`.)

You can use the full range of Unicode characters here. Instead of `me>nis` or `psukhe>`, write `mênis` and `psukê`. (You can also use a macron instead of a circumflex, if you prefer -- just be consistent.)

### Named entities

At times, you might wish to indicate the presence of a named entity in the line. To do so, you should format the entity as a link to its [Wikidata](https://wikidata.org) page, with the class of the entity included in curly brackets after the URL. For example:

```
[1] The anger [mênis] of [Peleus](https://www.wikidata.org/wiki/Q178641){.person}' son [Achilles](https://www.wikidata.org/wiki/Q41746){.person}, goddess, perform its song --
```

The goal is to use these manual annotations to help train a model for automating parts of this process.