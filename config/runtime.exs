import Config

config :ahcip,
  translation_zip: System.get_env("TRANSLATION_ZIP", "translation/ahcip.zip"),
  data_dir: System.get_env("DATA_DIR", "tei/data")
