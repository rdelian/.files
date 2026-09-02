function nvf {
    param([string]$FileName)

    if ($FileName) {
        $selection = es $FileName | fzf
    }

    if ($selection) {
        nvim $selection
    }
}