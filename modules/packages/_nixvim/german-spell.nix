{
  fetchFromGitHub,
  neovim-unwrapped,
  runCommand,
}:
let
  # The frami word lists with an affix file adapted to Vim's Hunspell
  # dialect. Vim's own runtime builds its published German spell file from
  # this repository, so this is the list Neovim would otherwise offer to
  # download from the Vim mirror at run time.
  src = fetchFromGitHub {
    owner = "Yamagi";
    repo = "vim-german-dictionaries";
    rev = "9b72068ddab141d6f85828013b148f0dbe99d4b3";
    hash = "sha256-HCvEVsMBJFYL6EiF+FrLDp4cr7fa6uhgC0wiI7VGFhI=";
  };
in
runCommand "nvim-spell-de" { nativeBuildInputs = [ neovim-unwrapped ]; } ''
  # Each input's base name becomes a region, so `spelllang=de_de` can mark an
  # Austrian or Swiss spelling as regional instead of as a mistake.
  for region in AT CH DE; do
    cp ${src}/src/de_''${region}_frami.aff de_$region.aff
    cp ${src}/src/de_''${region}_frami.dic de_$region.dic
  done

  export HOME=$TMPDIR
  nvim -u NONE -i NONE --headless \
    -c 'mkspell! de de_AT de_CH de_DE' -c 'qa!' </dev/null

  # mkspell reports some failures only as a message and still exits 0, so
  # the files themselves are the evidence that it finished. The suggestion
  # file comes from the affix file's soundfolding rules; the two share a
  # build timestamp that ties them together, so the output is not
  # bit-for-bit reproducible, only equivalent.
  test -s de.utf-8.spl
  test -s de.utf-8.sug
  install -Dm644 -t "$out/spell" de.utf-8.spl de.utf-8.sug
''
