import Config

config :kodon,
  translation_dir: System.get_env("TRANSLATION_DIR", "A Homeric translation IP/"),
  data_dir: System.get_env("DATA_DIR", "my/data/directory (SEE DOCUMENTATION)")
