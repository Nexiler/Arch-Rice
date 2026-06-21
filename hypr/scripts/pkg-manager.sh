#!/usr/bin/env bash

# ==============================================================================
# Arch/Hyprland TUI Package Manager (v3 - Smart Search)
# Aesthetic: Catppuccin Mocha (Omarchy Style)
# Dependencies: pacman, gum, yay/paru (optional)
# ==============================================================================

# --- Configuration & Styling ---
PRIMARY_COLOR="#cba6f7"   # Mauve
SECONDARY_COLOR="#89b4fa" # Blue
ERROR_COLOR="#f38ba8"     # Red
SUCCESS_COLOR="#a6e3a1"   # Green
TEXT_COLOR="#cdd6f4"      # Text

if ! command -v gum &> /dev/null; then
    echo -e "\e[31mError:\e[0m 'gum' is not installed."
    exit 1
fi

if command -v yay &> /dev/null; then
    PM=(yay)
    AUR_SUPPORT="Enabled (yay)"
elif command -v paru &> /dev/null; then
    PM=(paru)
    AUR_SUPPORT="Enabled (paru)"
else
    PM=(sudo pacman)
    AUR_SUPPORT="Disabled (Install 'yay' or 'paru')"
fi

draw_header() {
    clear
    gum style \
        --border rounded \
        --align center \
        --width 70 \
        --margin "1 1" \
        --padding "1 2" \
        --border-foreground "$PRIMARY_COLOR" \
        --foreground "$PRIMARY_COLOR" \
        --bold \
        "📦 ARCH/HYPRLAND PACKAGE MANAGER" \
        "" \
        "Backend: ${PM[0]} | AUR: $AUR_SUPPORT"
}

pause() {
    echo ""
    gum style --foreground "$SECONDARY_COLOR" --italic "Press Enter to return to the main menu..."
    read -r
}

handle_error() {
    echo ""
    gum style --foreground "$ERROR_COLOR" --bold "❌ An error occurred during the operation."
}

# --- Main Loop ---
while true; do
    draw_header
    
    CHOICE=$(gum choose \
        --cursor "❯ " \
        --cursor.foreground "$PRIMARY_COLOR" \
        --item.foreground "$TEXT_COLOR" \
        --selected.foreground "$SUCCESS_COLOR" \
        --height 10 \
        "🔍 Search & Install Packages" \
        "📥 Direct Install (Exact Name)" \
        "🗑️  Remove Package" \
        "🔄 Update System" \
        "🧹 Clean Cache & Orphans" \
        "🚪 Exit")

    case "$CHOICE" in
        "🔍 Search & Install Packages")
            draw_header
            gum style --foreground "$SECONDARY_COLOR" "Enter search term (e.g., firefox, waybar):"
            QUERY=$(gum input --placeholder "Type to search..." --width 50)
            
            if [[ -n "$QUERY" ]]; then
                echo ""
                gum style --foreground "$PRIMARY_COLOR" "⏳ Querying databases and prioritizing main packages..."
                
                # Lowercase the query for reliable matching logic
                LOW_QUERY=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

                # 1. Fetch and process Official Repos
                # Awk analyzes if the package name strictly matches your search query
                REPO_RESULTS=$(pacman -Ss "$QUERY" | awk -v q="$LOW_QUERY" '
                    NR%2==1 {
                        pkg_full = $1
                        split(pkg_full, parts, "/")
                        pkg_name = parts[2] ? parts[2] : parts[1]
                        installed = index(tolower($0), "nstall") > 0 ? "✅" : ""
                        
                        if (tolower(pkg_name) == q) {
                            printf "⭐ [CORE MATCH] %s %s ", installed, pkg_full
                        } else {
                            printf "🟦 [OFFICIAL]   %s %s ", installed, pkg_full
                        }
                    }
                    NR%2==0 {
                        sub(/^[ \t]+/, "")
                        print "- " $0
                    }')
                    
                # 2. Fetch and process AUR Repos
                AUR_RESULTS=""
                if [[ "${PM[0]}" != "sudo" ]]; then
                    AUR_RESULTS=$(${PM[0]} -Ssa "$QUERY" 2>/dev/null | awk -v q="$LOW_QUERY" '
                        NR%2==1 {
                            pkg_full = $1
                            split(pkg_full, parts, "/")
                            pkg_name = parts[2] ? parts[2] : parts[1]
                            installed = index(tolower($0), "nstall") > 0 ? "✅" : ""
                            
                            if (tolower(pkg_name) == q) {
                                printf "⭐ [CORE MATCH] %s %s ", installed, pkg_full
                            } else {
                                printf "🟪 [AUR]        %s %s ", installed, pkg_full
                            }
                        }
                        NR%2==0 {
                            sub(/^[ \t]+/, "")
                            print "- " $0
                        }')
                fi
                
                # 3. Structural Stratification (Bubble exact matches to the absolute top)
                ALL_RESULTS=$(echo -e "${REPO_RESULTS}\n${AUR_RESULTS}" | grep -v '^\s*$')
                
                if [[ -z "$ALL_RESULTS" ]]; then
                    echo ""
                    gum style --foreground "$ERROR_COLOR" "❌ No packages found for '$QUERY'."
                    pause
                    continue
                fi
                
                # Organize strings into distinct priority bands
                PRIORITIZED_LIST=$(echo "$ALL_RESULTS" | awk '
                    /^⭐/ { core = core $0 "\n" }
                    /^🟦/ { official = official $0 "\n" }
                    /^🟪/ { aur = aur $0 "\n" }
                    END { printf "%s%s%s", core, official, aur }
                ')
                
                draw_header
                gum style --foreground "$SUCCESS_COLOR" "💡 [TAB] to select multiple | [ENTER] to install"
                echo ""
                
                # Render prioritized interface
                SELECTED=$(echo "$PRIORITIZED_LIST" | gum filter --no-limit --indicator "❯" --indicator.foreground "$PRIMARY_COLOR" --height 18)
                
                if [[ -n "$SELECTED" ]]; then
                    # Safely extract package name string directly preceding the visual separator
                    PKGS_TO_INSTALL=$(echo "$SELECTED" | awk -F ' ' '{for(i=1;i<=NF;i++) if($i=="-"){print $(i-1); break}}')
                    
                    mapfile -t PKG_ARRAY <<< "$PKGS_TO_INSTALL"
                    
                    echo ""
                    gum style --foreground "$PRIMARY_COLOR" "🚀 Preparing installation for: ${PKG_ARRAY[*]}"
                    echo ""
                    if "${PM[@]}" -S "${PKG_ARRAY[@]}"; then
                        echo ""
                        gum style --foreground "$SUCCESS_COLOR" --bold "✅ Processing complete!"
                    else
                        handle_error
                    fi
                fi
                pause
            fi
            ;;

        "📥 Direct Install (Exact Name)")
            draw_header
            gum style --foreground "$SECONDARY_COLOR" "Enter exact package name(s):"
            PKG=$(gum input --placeholder "e.g., firefox neovim" --width 50)
            
            if [[ -n "$PKG" ]]; then
                read -ra PKG_ARRAY <<< "$PKG"
                echo ""
                gum style --foreground "$PRIMARY_COLOR" "🚀 Running: ${PM[*]} -S ${PKG_ARRAY[*]}"
                echo ""
                if "${PM[@]}" -S "${PKG_ARRAY[@]}"; then
                    echo ""
                    gum style --foreground "$SUCCESS_COLOR" --bold "✅ Installation complete!"
                else
                    handle_error
                fi
                pause
            fi
            ;;
            
        "🗑️  Remove Package")
            draw_header
            gum style --foreground "$SECONDARY_COLOR" "Loading explicitly installed packages..."
            
            PKG=$(pacman -Qqe | gum filter --placeholder "Type to search your installed packages..." --width 50 --indicator "❯" --indicator.foreground "$PRIMARY_COLOR")
            
            if [[ -n "$PKG" ]]; then
                draw_header
                gum style --foreground "$ERROR_COLOR" --bold "⚠️ Are you sure you want to remove '$PKG'?"
                gum style --foreground "$TEXT_COLOR" "This will also remove unused dependencies (-Rns)."
                echo ""
                
                CONFIRM=$(gum choose --cursor "❯ " --cursor.foreground "$ERROR_COLOR" "Yes, remove it" "Cancel")
                if [[ "$CONFIRM" == "Yes, remove it" ]]; then
                    echo ""
                    gum style --foreground "$PRIMARY_COLOR" "🚀 Running: ${PM[*]} -Rns $PKG"
                    echo ""
                    if "${PM[@]}" -Rns "$PKG"; then
                        echo ""
                        gum style --foreground "$SUCCESS_COLOR" --bold "✅ Successfully removed $PKG!"
                    else
                        handle_error
                    fi
                    pause
                fi
            fi
            ;;
            
        "🔄 Update System")
            draw_header
            echo ""
            gum style --foreground "$PRIMARY_COLOR" "🚀 Running: ${PM[*]} -Syu"
            echo ""
            if "${PM[@]}" -Syu; then
                echo ""
                gum style --foreground "$SUCCESS_COLOR" --bold "✅ System updated successfully!"
            else
                handle_error
            fi
            pause
            ;;
            
        "🧹 Clean Cache & Orphans")
            draw_header
            CLEAN_CHOICE=$(gum choose --cursor "❯ " --cursor.foreground "$PRIMARY_COLOR" "Orphaned Packages" "Package Cache" "Cancel")

            case "$CLEAN_CHOICE" in
                "Orphaned Packages")
                    ORPHANS=$(pacman -Qtdq || true)
                    if [[ -n "$ORPHANS" ]]; then
                        mapfile -t ORPHAN_ARRAY <<< "$ORPHANS"
                        echo ""
                        gum style --foreground "$PRIMARY_COLOR" "🚀 Removing orphans..."
                        echo ""
                        if "${PM[@]}" -Rns "${ORPHAN_ARRAY[@]}"; then
                            gum style --foreground "$SUCCESS_COLOR" "✅ Orphans removed!"
                        else
                            handle_error
                        fi
                    else
                        echo ""
                        gum style --foreground "$SUCCESS_COLOR" "✅ System clean! No orphaned packages found."
                    fi
                    pause
                    ;;
                "Package Cache")
                    echo ""
                    gum style --foreground "$PRIMARY_COLOR" "🚀 Clearing package cache..."
                    echo ""
                    if "${PM[@]}" -Sc; then
                        gum style --foreground "$SUCCESS_COLOR" "✅ Cache cleared!"
                    else
                        handle_error
                    fi
                    pause
                    ;;
            esac
            ;;
            
        "🚪 Exit")
            clear
            gum style --foreground "$PRIMARY_COLOR" --bold "Goodbye! ✌️"
            exit 0
            ;;
    esac
done
