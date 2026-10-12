function fish_greeting
    # Banner navideno (rojo/verde alternos)
    echo -ne '\x1b[91m'; echo '    ____       __     _             _ '
    echo -ne '\x1b[92m'; echo '   /  _/_____ / /_   (_)____ ___   (_)'
    echo -ne '\x1b[91m'; echo '   / / / ___// __ \ / // __ `__ \ / / '
    echo -ne '\x1b[92m'; echo ' _/ / (__  )/ / / // // / / / / // /  '
    echo -ne '\x1b[91m'; echo '/___//____//_/ /_//_//_/ /_/ /_//_/   '
    set_color normal
    command -v fastfetch &> /dev/null && fastfetch --key-padding-left 5
end
