import Config

config :ahcip,
  translation_dir: System.get_env("TRANSLATION_DIR", "A Homeric translation IP/"),
  butler_iliad_tei_path:
    System.get_env("BUTLER_ILIAD_TEI_PATH", "data/tlg0012/tlg001/tlg0012.tlg001.perseus-eng4.xml")
