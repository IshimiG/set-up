# Lo común de fish en todas las máquinas. Lo propio de una sola va en
# ~/.config/fish/conf.d/, fuera del repo; fish_variables tampoco entra en git.

# Los ejecutables del usuario (uv, claude, launch-or-focus…).
fish_add_path ~/.local/bin

if status is-interactive
    # Prompt de Starship
    command -v starship &> /dev/null && starship init fish | source

    # Direnv y zoxide (cd salta a las carpetas que más se usan)
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # Un ls mejor
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # Abreviaturas
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Marca el inicio de cada prompt, para saltar entre prompts en la terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end
