# Cycle — common tasks. `just` lists them. Recipes run in fish.

set shell := ["fish", "-c"]

app := "build/Cycle.app"
bundle_id := "com.zms.Cycle"

alias b := build
alias r := run

default:
    @just --list

# Build build/Cycle.app (release by default; `just build debug` for debug)
build config="release":
    #!/usr/bin/env fish
    swift build -c {{ config }}; or exit 1
    set -l bin (swift build -c {{ config }} --show-bin-path)
    rm -rf "{{ app }}"
    mkdir -p "{{ app }}/Contents/MacOS" "{{ app }}/Contents/Resources"
    cp "$bin/Cycle" "{{ app }}/Contents/MacOS/Cycle"
    cp Support/Info.plist "{{ app }}/Contents/Info.plist"
    cp Support/AppIcon.icns Support/MenuBarIcon.svg "{{ app }}/Contents/Resources/"
    xattr -cr "{{ app }}"
    # A stable signing identity keeps the Accessibility grant across rebuilds;
    # ad hoc signing means re-granting after each build.
    if set -q CYCLE_SIGN_IDENTITY
        codesign --force --sign "$CYCLE_SIGN_IDENTITY" "{{ app }}"; or exit 1
    else
        # Ad hoc, but with a designated requirement of just the bundle id: the default ad hoc
        # requirement is the cdhash, which changes every build, so macOS would stop matching
        # the Accessibility / Screen Recording grants after each rebuild.
        codesign --force --sign - --identifier {{ bundle_id }} \
            --requirements '=designated => identifier "{{ bundle_id }}"' "{{ app }}"; or exit 1
    end
    echo "Built {{ app }}"

# Build, quit any running copy, and open the fresh build
run config="release": (build config)
    -pkill -x Cycle
    open "{{ app }}"

# Reset Cycle's Accessibility and Screen Recording grants (after an ad hoc rebuild)
reset-permissions:
    -tccutil reset Accessibility {{ bundle_id }}
    -tccutil reset ScreenCapture {{ bundle_id }}

# Rebuild Support/AppIcon.icns from an SVG in Support/Icons (default: cycle-minimal)
icon name="cycle-minimal":
    #!/usr/bin/env fish
    set -l tmp (mktemp -d)
    mkdir -p $tmp/AppIcon.iconset
    # Quick Look renders SVG without extra tools.
    qlmanage -t -s 1024 -o $tmp "Support/Icons/{{ name }}.svg" >/dev/null 2>&1; or exit 1
    set -l src $tmp/{{ name }}.svg.png
    for sz in 16 32 128 256 512
        sips -z $sz $sz $src --out $tmp/AppIcon.iconset/icon_{$sz}x{$sz}.png >/dev/null
        set -l d (math $sz \* 2)
        sips -z $d $d $src --out $tmp/AppIcon.iconset/icon_{$sz}x{$sz}@2x.png >/dev/null
    end
    iconutil -c icns $tmp/AppIcon.iconset -o Support/AppIcon.icns; and echo "Wrote Support/AppIcon.icns from {{ name }}"
    rm -rf $tmp
