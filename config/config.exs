import Config

config :kodon,
  output_dir: "output",
  site_title: "A Homeric Commentary in Progress",
  commentary_dir: "commentary",
  commentary_dump_path: "my_commentary_pg_dump.db",
  templates_dir: Path.expand("../priv/templates", __DIR__),
  cross_ref_prefix: "I",
  cross_ref_default_slug: "tlg0012.tlg001"
