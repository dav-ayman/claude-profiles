# Terminal demo for the README. Regenerate with:  vhs docs/demo.tape
# Runs in a throwaway HOME, so it never touches your real profiles.

Output docs/images/demo.gif

Set Shell "bash"
Set FontSize 20
Set Width 1240
Set Height 700
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set WindowBar Colorful

Hide
Type "export DEMO=$(mktemp -d) && export HOME=$DEMO/you XDG_CONFIG_HOME=$DEMO/you/.config && mkdir -p $HOME/.local/bin && ln -s $(command -v claude) $HOME/.local/bin/claude 2>/dev/null; export PATH=$PWD/bin:$HOME/.local/bin:/usr/bin:/bin PS1='\[\e[32m\]$\[\e[0m\] ' && clear"
Enter
Sleep 500ms
Show

Type "claude-profiles add work --default"
Sleep 400ms
Enter
Sleep 2.5s

Type "claude-profiles add personal"
Sleep 400ms
Enter
Sleep 3s

Type "clear && claude-profiles list"
Enter
Sleep 3s

Type "claude-personal --version"
Sleep 400ms
Enter
Sleep 2.5s

Type "ls ~/Applications"
Enter
Sleep 3.5s
