{ pkgs ? (import <nixpkgs> { }), ... }:
with pkgs;
let
  otp = beam.packages.erlang_27;
  elixir = otp.elixir_1_17.overrideAttrs (oldAttrs: {
    version = "1.18-dev";
    src = fetchFromGitHub {
      owner = "elixir-lang";
      repo = "elixir";
      rev = "b799e9eda4613a1bc40fd0824fb08d5df3b3e24b";
      sha256 = "sha256-mTG9/Qk/kXoVdWL9oBv1WuNMyQjIINx8Gpi91l6oS4M=";
    };
  });
in
pkgs.mkShell {
  buildInputs = [
    elixir
    otp.erlang
    ((if otp ? elixir-ls then otp.elixir-ls else otp.elixir_ls).override { inherit elixir; })
  ];

  shellHook = ''
    # keep your shell history in iex
    export ERL_AFLAGS="-kernel shell_history enabled"

    # Force UTF8 in CLI
    export LANG="C.UTF-8"

    # this isolates mix to work only in local directory
    mkdir -p .nix-mix .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex

    # make hex from Nixpkgs available
    # `mix local.hex` will install hex into MIX_HOME and should take precedence
    export MIX_PATH="${otp.hex}/lib/erlang/lib/hex/ebin"
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
  '';
}
