gleam test
fswatch -o src test | xargs -n1 -I{} gleam test