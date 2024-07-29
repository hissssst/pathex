{
  description = "Pathex: Elixir language lenses and Access replacement";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs =
    { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux; in
    {
      devShells.x86_64-linux.default = import ./shell.nix { inherit pkgs; };
    };
}
