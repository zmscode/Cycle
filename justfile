# Cycle — common tasks. `just` lists them. Recipes run in fish.

set shell := ["fish", "-c"]

app := "build/Cycle.app"
bundle_id := "com.zms.Cycle"
version := trim(read("VERSION"))
# Where releases are published, and the Homebrew tap that installs them.
github := "zmscode/Cycle"
tap := "zmscode/homebrew-cycle"

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
    cp Support/AppIcon.icns "{{ app }}/Contents/Resources/"
    # The version from VERSION; the build number counts commits.
    set -l build_number (git rev-list --count HEAD 2>/dev/null; or echo 1)
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleShortVersionString {{ version }}" \
        -c "Set :CFBundleVersion $build_number" \
        "{{ app }}/Contents/Info.plist"
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
    echo "Built {{ app }} ({{ version }} build $build_number)"

# Build, quit any running copy, and open the fresh build
run config="release": (build config)
    -pkill -x Cycle
    open "{{ app }}"

# Reset Cycle's Accessibility and Screen Recording grants (after an ad hoc rebuild)
reset-permissions:
    -tccutil reset Accessibility {{ bundle_id }}
    -tccutil reset ScreenCapture {{ bundle_id }}

# Zip build/Cycle.app as build/Cycle-<version>.zip and print its SHA-256
package: build
    #!/usr/bin/env fish
    set -l zip "build/Cycle-{{ version }}.zip"
    rm -f "$zip"
    # ditto keeps the bundle's symlinks, extended attributes and signature intact.
    ditto -c -k --sequesterRsrc --keepParent "{{ app }}" "$zip"; or exit 1
    shasum -a 256 "$zip"

# Publish v<VERSION> on GitHub and point the Homebrew tap at it. Bump VERSION first.
release: package
    #!/usr/bin/env fish
    set -l zip "build/Cycle-{{ version }}.zip"
    set -l sha (shasum -a 256 "$zip" | cut -d' ' -f1)
    if not git diff --quiet; or not git diff --cached --quiet
        echo "Commit your changes before releasing."; exit 1
    end
    git push origin HEAD; or exit 1
    gh release create "v{{ version }}" "$zip" --repo {{ github }} \
        --title "Cycle {{ version }}" --notes "Install with: brew install --cask zmscode/cycle/cycle"; or exit 1
    # Update the cask in the tap with this version and checksum.
    rm -rf build/tap
    gh repo clone {{ tap }} build/tap; or exit 1
    # Commit to the tap as the same author as this repo.
    git -C build/tap config user.name (git config user.name)
    git -C build/tap config user.email (git config user.email)
    mkdir -p build/tap/Casks
    sed -e 's/^  version ".*"/  version "{{ version }}"/' -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
        Casks/cycle.rb > build/tap/Casks/cycle.rb
    cd build/tap
    git add Casks/cycle.rb
    git commit -m "Cycle {{ version }}" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; and git push; or exit 1
    echo "Released Cycle {{ version }}: brew install --cask zmscode/cycle/cycle"
