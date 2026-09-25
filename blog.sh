#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

marker='<meta name="generator" content="blog.sh">'

usage() {
    cat <<EOF
usage: ./blog.sh [command] [name]

  sync         build every post in blog/ and rebuild the list (default)
  add <name>   build blog/<name>/ and add it to the list
  rm <name>    delete blog/<name>/ (asks first) and remove it from the list
  new <name>   create blog/<name>/post.md, dated today
  list         show all posts and whether they're published

<name> is the post's folder name, e.g. "my-post" or "blog/my-post".
EOF
}

die() { echo "$*" >&2; exit 1; }

header() {
    awk -v key="$1" '
        NR == 1 && $0 == "---"             { inside = 1; next }
        inside && $0 == "---"              { exit }
        inside && index($0, key ":") == 1  { sub("^" key ":[ \t]*", ""); print; exit }
    ' "$2"
}

body() {
    awk '
        NR == 1 && $0 == "---"  { inside = 1; next }
        inside && $0 == "---"   { inside = 0; next }
        !inside
    ' "$1"
}

escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

is_generated() {
    [ -e "$1" ] && head -n 10 "$1" | grep -qF "$marker"
}

name_of() 
    local name=${1%/}
    name=${name#blog/}
    [ -n "$name" ] && [[ $name != */* ]] || die "bad post name: $1"
    echo "$name"
}

md_of() {
    local mds=("$1"/*.md)
    [ ${#mds[@]} -eq 1 ] || return 1
    echo "${mds[0]}"
}

build() {
    local dir="blog/$1" out="blog/$1/index.html" md title date desc content
    [ -d "$dir" ] || { echo "no such post: $dir" >&2; return 1; }
    [[ $1 == _* ]] && { echo "$dir is a draft, rename it without the _ to publish" >&2; return 1; }
    md=$(md_of "$dir") || { echo "skipping $dir: needs exactly one .md file" >&2; return 1; }
    if [ -e "$out" ] && ! is_generated "$out"; then
        echo "skipping $dir: $out was not made by this script, not overwriting it" >&2
        return 1
    fi

    title=$(header title "$md" | escape)
    date=$(header date "$md" | escape)
    desc=$(header description "$md" | escape)
    if [ -z "$title" ] || [ -z "$date" ]; then
        echo "skipping $md: missing title or date in the header" >&2
        return 1
    fi

    content=$(mktemp)
    body "$md" | cmark --unsafe --smart > "$content"

    TITLE=$title DATE=$date DESC=$desc SOURCE=${md##*/} awk -v cf="$content" '
        function rep(s, k, v,    i, out) {
            out = ""
            while ((i = index(s, k)) > 0) {
                out = out substr(s, 1, i - 1) v
                s = substr(s, i + length(k))
            }
            return out s
        }
        BEGIN { while ((getline line < cf) > 0) body = body line "\n" }
        $0 == "{{content}}" { printf "%s", body; next }
        {
            $0 = rep($0, "{{title}}", ENVIRON["TITLE"])
            $0 = rep($0, "{{date}}", ENVIRON["DATE"])
            $0 = rep($0, "{{description}}", ENVIRON["DESC"])
            $0 = rep($0, "{{source}}", ENVIRON["SOURCE"])
            print
        }
    ' templates/post.html > "$out"
    rm -f "$content"
    echo "built $out"
}

write_list() {
    local dir name md out rows block title date desc
    rows=$(mktemp)
    block=$(mktemp)

    for dir in blog/*/; do
        dir=${dir%/}
        name=${dir#blog/}
        out="$dir/index.html"
        [[ $name == _* ]] && continue
        is_generated "$out" || continue
        if ! md=$(md_of "$dir"); then
            rm -f "$out"
            echo "removed $out (no .md left in $dir)"
            continue
        fi
        title=$(header title "$md" | escape)
        date=$(header date "$md" | escape)
        desc=$(header description "$md" | escape)
        printf '%s\t%s\t%s\t%s\n' "$date" "$name" "$title" "$desc" >> "$rows"
    done

    sort -r "$rows" | while IFS=$'\t' read -r date name title desc; do
        echo "                <li class=\"entry\">"
        echo "                    <h1><a href=\"blog/$name/index.html\">$title</a></h1>"
        [ -n "$desc" ] && echo "                    <h2>$desc</h2>"
        echo "                    <span class=\"date\">$date</span>"
        echo "                </li>"
    done > "$block"

    [ -s "$block" ] || echo "                <li class=\"empty\">nothing here yet</li>" > "$block"

    if ! grep -q '<ul class="links posts">' index.html; then
        rm -f "$rows" "$block"
        die 'index.html is missing the <ul class="links posts"> list'
    fi

    awk '
        FNR == NR                         { list = list $0 "\n"; next }
        skip && /<\/ul>/                  { printf "%s", list; skip = 0 }
        !skip                             { print }
        /<ul class="links posts">/        { skip = 1 }
    ' "$block" index.html > index.html.tmp
    mv index.html.tmp index.html

    echo "updated index.html ($(grep -c 'class="entry"' "$block" || true) post(s) listed)"
    rm -f "$rows" "$block"
}

need_cmark() {
    command -v cmark >/dev/null || die "cmark not found, install it first"
}

cmd=${1:-sync}
case $cmd in
    sync)
        need_cmark
        for dir in blog/*/; do
            name=${dir%/}; name=${name#blog/}
            [[ $name == _* ]] && continue
            [ -n "$(echo "$dir"*.md)" ] || continue
            build "$name" || true
        done
        write_list
        ;;
    add)
        [ $# -eq 2 ] || { usage; exit 1; }
        need_cmark
        name=$(name_of "$2")
        build "$name"
        write_list
        ;;
    rm)
        [ $# -eq 2 ] || { usage; exit 1; }
        name=$(name_of "$2")
        [ -d "blog/$name" ] || die "no such post: blog/$name"
        echo "this deletes blog/$name/ and everything in it:"
        ls -A "blog/$name" | sed 's/^/  /'
        read -r -p "delete it? [y/N] " answer
        [[ $answer == [yY]* ]] || die "nothing deleted"
        rm -rf -- "blog/$name"
        echo "deleted blog/$name"
        write_list
        ;;
    new)
        [ $# -eq 2 ] || { usage; exit 1; }
        name=$(name_of "$2")
        [ -e "blog/$name" ] && die "blog/$name already exists"
        mkdir "blog/$name"
        md="blog/$name/post.md"
        printf -- '---\ntitle: %s\ndate: %s\ndescription:\n---\n\nWrite your post here. See blog/_example/post.md for what you can do.\n' \
            "$name" "$(date +%F)" > "$md"
        echo "created $md, write your post there and run: ./blog.sh add $name"
        ;;
    list)
        for dir in blog/*/; do
            dir=${dir%/}
            name=${dir#blog/}
            if [[ $name == _* ]]; then
                status=draft
            elif is_generated "$dir/index.html"; then
                status=published
            else
                status="not built"
            fi
            title="" date=""
            if md=$(md_of "$dir"); then
                title=$(header title "$md")
                date=$(header date "$md")
            fi
            printf '%-10s  %-10s  %-24s  %s\n' "$status" "${date:--}" "$name" "$title"
        done
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
