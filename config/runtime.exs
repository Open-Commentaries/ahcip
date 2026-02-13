import Config

config :ahcip,
  translation_dir: System.get_env("TRANSLATION_DIR", "A Homeric translation IP/"),
  data_dir: System.get_env("DATA_DIR", "data")
