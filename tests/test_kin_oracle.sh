#!/bin/bash
###################################################################
# test_kin_oracle.sh
# Test suite for tools/kin_oracle.sh — Oracle Dreamspell / Kin Maya
#
# Purpose: verrouiller par des tests les invariants mathématiques des
# 5 pouvoirs (Guide, Antipode, Analogue, Occulte) sur les 260 Kin, afin
# qu'une future modification ne puisse plus faire dériver silencieusement
# le code de sa documentation (cf. l'incohérence trouvée dans le SVG
# "5 Pouvoirs Oracle" de UPlanet/earth/miz.html, corrigée le même jour).
#
# Ne fait aucun appel réseau : pure arithmétique bash.
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

source "$MY_PATH/test_common.sh"
source "$MY_PATH/../tools/kin_oracle.sh"

# ─── Bijectivité + involution de _kin_antipode ───────────────────────────────
test_antipode_bijective_involution() {
    test_log_info "Antipode : bijection + involution sur les 260 Kin..."
    local -a seen=()
    local fail_bij=0 fail_inv=0
    for ((k=1; k<=260; k++)); do
        local a; a=$(_kin_antipode "$k")
        [[ -z "${seen[$a]:-}" ]] || { fail_bij=$((fail_bij+1)); }
        seen[$a]=1
        local aa; aa=$(_kin_antipode "$a")
        [[ "$aa" -eq "$k" ]] || { fail_inv=$((fail_inv+1)); echo "  ✗ antipode(antipode($k))=$aa ≠ $k" >&2; }
    done
    assert_equal "0" "$fail_bij" "Antipode est une bijection sur [1,260]"
    assert_equal "0" "$fail_inv" "Antipode est une involution (antipode(antipode(K))=K)"
}

# ─── Bijectivité + involution de _kin_analog ─────────────────────────────────
test_analog_bijective_involution() {
    test_log_info "Analogue : bijection + involution sur les 260 Kin..."
    local -a seen=()
    local fail_bij=0 fail_inv=0
    for ((k=1; k<=260; k++)); do
        local a; a=$(_kin_analog "$k")
        [[ -z "${seen[$a]:-}" ]] || { fail_bij=$((fail_bij+1)); }
        seen[$a]=1
        local aa; aa=$(_kin_analog "$a")
        [[ "$aa" -eq "$k" ]] || { fail_inv=$((fail_inv+1)); echo "  ✗ analog(analog($k))=$aa ≠ $k" >&2; }
    done
    assert_equal "0" "$fail_bij" "Analogue est une bijection sur [1,260]"
    assert_equal "0" "$fail_inv" "Analogue est une involution (analog(analog(K))=K)"
}

# ─── Antipode et Analogue partagent le même sceau (sceau+10) ─────────────────
test_antipode_analog_share_seal() {
    test_log_info "Antipode et Analogue partagent le même sceau (sceau+10)..."
    local fail=0
    for ((k=1; k<=260; k++)); do
        local sa; sa=$(_kin_seal "$(_kin_antipode "$k")")
        local sn; sn=$(_kin_seal "$(_kin_analog "$k")")
        [[ "$sa" -eq "$sn" ]] || { fail=$((fail+1)); echo "  ✗ K=$k : sceau(antipode)=$sa ≠ sceau(analog)=$sn" >&2; }
    done
    assert_equal "0" "$fail" "sceau(Antipode(K)) == sceau(Analogue(K)) pour tout K"
}

# ─── Identité : ton(Occulte) == ton(Antipode) (les deux inversent 14-T) ──────
test_occult_antipode_share_tone() {
    test_log_info "Occulte et Antipode partagent le même ton (14-T)..."
    local fail=0
    for ((k=1; k<=260; k++)); do
        local occ=$(( 261 - k ))
        local t_occ; t_occ=$(_kin_tone "$occ")
        local t_anti; t_anti=$(_kin_tone "$(_kin_antipode "$k")")
        [[ "$t_occ" -eq "$t_anti" ]] || { fail=$((fail+1)); echo "  ✗ K=$k : ton(occulte)=$t_occ ≠ ton(antipode)=$t_anti" >&2; }
    done
    assert_equal "0" "$fail" "ton(Occulte(K)) == ton(Antipode(K)) pour tout K"
}

# ─── Occulte : symétrie exacte (sceaux somment à 19, tons à 14) ──────────────
test_occult_symmetry() {
    test_log_info "Occulte : sceau miroir (19-sceau), ton complémentaire (14-ton)..."
    local fail_s=0 fail_t=0
    for ((k=1; k<=260; k++)); do
        local occ=$(( 261 - k ))
        local s1; s1=$(_kin_seal "$k"); local s2; s2=$(_kin_seal "$occ")
        (( s1 + s2 == 19 )) || { fail_s=$((fail_s+1)); }
        local t1; t1=$(_kin_tone "$k"); local t2; t2=$(_kin_tone "$occ")
        (( t1 + t2 == 14 )) || { fail_t=$((fail_t+1)); }
    done
    assert_equal "0" "$fail_s" "sceau(K) + sceau(Occulte(K)) == 19 pour tout K"
    assert_equal "0" "$fail_t" "ton(K) + ton(Occulte(K)) == 14 pour tout K"
}

# ─── Collision Antipode=Analogue exactement au ton 7 (20 cas, 1 par sceau) ───
test_tone7_collision() {
    test_log_info "Collision Antipode=Analogue : seulement au ton 7 (20 Kin)..."
    local collisions=0 fail_wrong_tone=0
    for ((k=1; k<=260; k++)); do
        local a; a=$(_kin_antipode "$k")
        local n; n=$(_kin_analog "$k")
        if [[ "$a" -eq "$n" ]]; then
            collisions=$((collisions+1))
            local t; t=$(_kin_tone "$k")
            [[ "$t" -eq 7 ]] || { fail_wrong_tone=$((fail_wrong_tone+1)); echo "  ✗ K=$k collision hors ton 7 (T=$t)" >&2; }
        fi
    done
    assert_equal "20" "$collisions" "Exactement 20 Kin (1 par sceau) ont Antipode == Analogue"
    assert_equal "0" "$fail_wrong_tone" "Toutes les collisions Antipode=Analogue sont au ton 7"
}

# ─── Guide : domaine valide + même famille-couleur (sceau%4) que soi ─────────
test_guide_range_and_family() {
    test_log_info "Guide : Kin valide [1,260] + même famille-couleur (sceau%4)..."
    local fail_range=0 fail_family=0
    for ((k=1; k<=260; k++)); do
        local g; g=$(_kin_guide "$k")
        if (( g < 1 || g > 260 )); then
            fail_range=$((fail_range+1)); echo "  ✗ guide($k)=$g hors [1,260]" >&2
            continue
        fi
        local fam_k=$(( $(_kin_seal "$k") % 4 ))
        local fam_g=$(( $(_kin_seal "$g") % 4 ))
        [[ "$fam_k" -eq "$fam_g" ]] || { fail_family=$((fail_family+1)); echo "  ✗ K=$k : famille(K)=$fam_k ≠ famille(guide)=$fam_g" >&2; }
    done
    assert_equal "0" "$fail_range" "Guide(K) est toujours un Kin valide (1-260)"
    assert_equal "0" "$fail_family" "Guide(K) appartient toujours à la même famille-couleur que K (sceau%4)"
}

# ─── Run all ──────────────────────────────────────────────────────────────────
echo "=========================================="
echo "  Test Suite: Kin Oracle (Dreamspell)"
echo "=========================================="

test_antipode_bijective_involution
test_analog_bijective_involution
test_antipode_analog_share_seal
test_occult_antipode_share_tone
test_occult_symmetry
test_tone7_collision
test_guide_range_and_family

print_test_summary
