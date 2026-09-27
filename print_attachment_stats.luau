-- print_attachment_stats.luau
-- Prints aggregated attachment statistics (kills and top weapon) across all weapons.
-- Displays polished in-game/formatted names instead of backend technical IDs.
-- Displays ALL attachments found (no truncation).
-- Legacy attachment ids are folded into their current ids via ATTACHMENT_ALIASES
-- (snapshot of deadline-balancing renames.csv), so renamed or merged parts
-- (e.g. both Vector bolts -> kalis_scalar_std_bcg) report unified totals.
--
-- How to call in the Luau Server Console:
--   1. Paste the script contents or run:
--        require("https://raw.githubusercontent.com/<user>/deadline-stat-printer/main/print_attachment_stats.luau")
--   2. For subsequent calls in the same server session:
--        shared.print_attachment_stats()                      -- default (first human player)
--        shared.print_attachment_stats(players.get("Name"))   -- specific player

-- BEGIN ATTACHMENT_ALIASES (generated from deadline-balancing renames.csv - do not edit by hand; use build_attachment_aliases.py)
local ATTACHMENT_ALIASES = {
    ["45acp_kriss_magex2_pf940"] = "kalis_kosch_45acp_17r_magex2",
    ["5.8x42_sanxian_dfv18_76gr_hp"] = "5.8x42_sanxian_dvf18_76gr_hp",
    ["7.62x54r_norilsk_7t2_149gr_green_tracer"] = "7.62x54r_norilsk_7t2m_149gr_green_tracer",
    ["7.62x54r_zim_rifle_150gr_spbt"] = "7.62x54r_pga_rifle_150gr_spbt",
    ["9x19_kriss_magex2_glock"] = "kalis_kosch_9x19_23r_magex2",
    ["9x19_pf940_std_17r_vector"] = "kosch_9x19_17r_magazine",
    ["9x19_sgmt_drum50r_vector"] = "fst_kosch_9x19_50r_drum_magazine",
    ["aeroknox_ae01_muzzle_brake"] = "equinox_ae01_muzzle_brake",
    ["aeroknox_ax15_10.5inch_handguard"] = "equinox_ex15_10.5inch_handguard",
    ["aeroknox_ax15_endplate"] = "equinox_ex15_endplate",
    ["aeroknox_ax15_front_sight"] = "equinox_ex15_front_sight",
    ["aeroknox_ax15_front_sight_base"] = "equinox_ex15_front_sight_base",
    ["aeroknox_ax15_front_sight_folded"] = "equinox_ex15_front_sight_folded",
    ["aeroknox_ax15_lower_receiver"] = "equinox_ex15_lower_receiver",
    ["aeroknox_ax15_lower_receiver_ar9"] = "equinox_ex15_lower_receiver_ar9",
    ["aeroknox_ax15_orion_pistol_grip"] = "equinox_ex15_orion_pistol_grip",
    ["aeroknox_ax15_rear_sight"] = "equinox_ex15_rear_sight",
    ["aeroknox_ax15_rear_sight_base"] = "equinox_ex15_rear_sight_base",
    ["aeroknox_ax15_rear_sight_folded"] = "equinox_ex15_rear_sight_folded",
    ["aeroknox_ax15_upper_receiver"] = "equinox_ex15_upper_receiver",
    ["aeroknox_ax_mlok_cover"] = "equinox_ex_mlok_cover",
    ["aeroknox_ax_mlok_cover_flipped"] = "equinox_ex_mlok_cover_flipped",
    ["aeroknox_ax_mlok_grip"] = "equinox_ex_mlok_grip",
    ["aeroknox_ax_mp5_modified_trigger_housing"] = "equinox_ex_mp5_modified_trigger_housing",
    ["aeroknox_ax_mp5_trigger_housing"] = "equinox_ex_mp5_trigger_housing",
    ["aeroknox_plus_5_pmag_mag_extension"] = "equinox_plus_5_pmag_mag_extension",
    ["azimuth_acro_kosch_adapter_plate"] = "azimuth_ecro_kosch_adapter_plate",
    ["azimuth_acro_p2_reflex_sight"] = "azimuth_ecro_p2_reflex_sight",
    ["azimuth_compm2_sight"] = "azimuth_duty2_sight",
    ["azimuth_compm4_sight"] = "azimuth_duty4_sight",
    ["azimuth_compm5_lens_caps"] = "azimuth_duty5_lens_caps",
    ["azimuth_compm5_sight"] = "azimuth_duty5_sight",
    ["bcm_gunfighter_kag"] = "ecm_gunslinger_kag",
    ["bcm_gunfighter_mod3_ar15_pistol_grip"] = "ecm_gunslinger_mod3_ar15_pistol_grip",
    ["bcm_gunfighter_mod3_mlok_foregrip"] = "ecm_gunslinger_mod3_mlok_foregrip",
    ["bcm_gunfighter_mod3_mlok_foregrip_flipped"] = "ecm_gunslinger_mod3_mlok_foregrip_flipped",
    ["bcm_gunfighter_mod3_mlok_shortened_foregrip"] = "ecm_gunslinger_mod3_mlok_shortened_foregrip",
    ["bcm_gunfighter_mod3_mlok_shortened_foregrip_flipped"] = "ecm_gunslinger_mod3_mlok_shortened_foregrip_flipped",
    ["bcm_gunfighter_mod3_picatinny_foregrip"] = "ecm_gunslinger_mod3_picatinny_foregrip",
    ["bcm_gunfighter_mod3_picatinny_foregrip_flipped"] = "ecm_gunslinger_mod3_picatinny_foregrip_flipped",
    ["bcm_gunfighter_mod3_picatinny_shortened_foregrip"] = "ecm_gunslinger_mod3_picatinny_shortened_foregrip",
    ["bcm_gunfighter_mod3_picatinny_shortened_foregrip_flipped"] = "ecm_gunslinger_mod3_picatinny_shortened_foregrip_flipped",
    ["bravo_comp_gunfighter_charging_handle"] = "ecm_gunslinger_charging_handle",
    ["bt_qd_nar_acro_22mm_mount"] = "bt_qd_nar_ecro_22mm_mount",
    ["bt_qd_nar_acro_30mm_mount"] = "bt_qd_nar_ecro_30mm_mount",
    ["bt_qd_nar_acro_39mm_mount"] = "bt_qd_nar_ecro_39mm_mount",
    ["cartesia_productions_x_fal_drum_mag_50r"] = "cartesia_productions_x_far_drum_mag_50r",
    ["corvus_defensio_aug_a3_mlok_top_rail"] = "aquila_defensio_aug_a3_mlok_top_rail",
    ["corvus_defensio_aug_case_deflector"] = "aquila_defensio_aug_case_deflector",
    ["corvus_defensio_aug_charging_handle"] = "aquila_defensio_aug_charging_handle",
    ["corvus_defensio_aug_enhanced_release_button"] = "aquila_defensio_aug_enhanced_release_button",
    ["corvus_defensio_aug_forward_accessory_rail"] = "aquila_defensio_aug_forward_accessory_rail",
    ["corvus_defension_m1_aug_receiver_rail"] = "aquila_defension_m1_aug_receiver_rail",
    ["fn_fal_7.62x51_belgian_flash_hider"] = "af_far_7.62x51_belgian_flash_hider",
    ["fn_fal_austrian_7.62x51_stg58_flash_hider"] = "af_far_austrian_7.62x51_stg58_flash_hider",
    ["fn_fal_long_carry_handle"] = "af_far_long_carry_handle",
    ["fn_fal_std_dust_cover"] = "af_far_std_dust_cover",
    ["fnb_precision_fal_crosshair_front_sight"] = "fnb_precision_far_crosshair_front_sight",
    ["fnb_precision_fal_duplex_front_sight"] = "fnb_precision_far_duplex_front_sight",
    ["glock17_auto_sear"] = "kosch_metal_auto_sear",
    ["holosun_he510c-gr_sight"] = "holostar_hx510c_gr_reflex",
    ["holosun_hs510c_sight"] = "holostar_hx510c_reflex",
    ["kosch_default_10mm_mag_plate"] = "kosch_default_large_mag_plate",
    ["kosch_default_9x19_mag_plate"] = "kosch_default_small_mag_plate",
    ["kriss_vector_gen2_folding_stock"] = "kalis_scalar_gen1_fsbl00_hinged_folding_stock",
    ["kriss_vector_non_folding_stock_adapter"] = "kalis_scalar_gen1_sabl00_hinged_buffer_tube_adapter",
    ["lowenhurz_aug_hbar_620mm_heavy_barrel"] = "lowenherz_aug_hbar_620mm_heavy_barrel",
    ["lowenhurz_aug_hbar_folding_bipod"] = "lowenherz_aug_hbar_folding_bipod",
    ["magtap_moe_butt_pad"] = "magtap_moa_butt_pad",
    ["magtap_moe_carbine_stock"] = "magtap_moa_carbine_stock",
    ["magtap_moe_sl_k_carbine_stock"] = "magtap_moa_sl_k_carbine_stock",
    ["magtap_moe_sl_k_carbine_stock_buttpad"] = "magtap_moa_sl_k_carbine_stock_buttpad",
    ["nm_fal_polymer_mag_20r"] = "nm_far_polymer_mag_20r",
    ["nowa_gen3_ar15_upper_receiver"] = "novacek_gen3_ar15_upper_receiver",
    ["nowa_love_ar15_charging_handle"] = "novacek_love_ar15_charging_handle",
    ["nowa_marked_vyctor_mur1s_ar15_upper_receiver"] = "novacek_marked_vyctor_mur1s_ar15_upper_receiver",
    ["nowa_n4_gen3_ar15_lower_receiver"] = "novacek_n4_gen3_ar15_lower_receiver",
    ["nowa_n4_gen3_ar15_lower_receiver_ar9"] = "novacek_n4_gen3_ar15_lower_receiver_ar9",
    ["nowa_n4_nsr_gen3_handguard_9.15inch"] = "novacek_n4_nsr_gen3_handguard_9.15inch",
    ["pf940_std_13r_vector_remodel"] = "kosch_45acp_13r_magazine",
    ["pmm_bcm_gunfighter_mod3_scar_pistol_grip"] = "pww_ecm_gunslinger_mod3_scar_pistol_grip",
    ["protac_ergonomic_ag_fal_pistol_grip"] = "protac_ergonomic_ag_far_pistol_grip",
    ["romeo4t_folded_lens_caps"] = "scipio4t_folded_lens_caps",
    ["romeo4t_lens_caps"] = "scipio4t_lens_caps",
    ["rsa_sa58_210mm_premium_pistol_barrel"] = "rsa_sg58_210mm_premium_pistol_barrel",
    ["rsa_sa58_305mm_barrel"] = "rsa_sg58_305mm_barrel",
    ["rsa_sa58_330mm_barrel"] = "rsa_sg58_330mm_barrel",
    ["rsa_sa58_406mm_barrel"] = "rsa_sg58_406mm_barrel",
    ["rsa_sa58_406mm_fluted_barrel"] = "rsa_sg58_406mm_fluted_barrel",
    ["rsa_sa58_457mm_barrel"] = "rsa_sg58_457mm_barrel",
    ["rsa_sa58_533mm_barrel"] = "rsa_sg58_533mm_barrel",
    ["rsa_sa58_7.62x51_bolt"] = "rsa_sg58_7.62x51_bolt",
    ["rsa_sa58_belgian_style_full_length_handguard"] = "rsa_sg58_belgian_style_full_length_handguard",
    ["rsa_sa58_belgian_style_mid_length_handguard"] = "rsa_sg58_belgian_style_mid_length_handguard",
    ["rsa_sa58_buttpad"] = "rsa_sg58_buttpad",
    ["rsa_sa58_enhanced_bumper_magazine_bottom_plate"] = "rsa_sg58_enhanced_bumper_magazine_bottom_plate",
    ["rsa_sa58_fal_metric_magazine_10r"] = "rsa_sg58_far_metric_magazine_10r",
    ["rsa_sa58_fal_metric_magazine_20r"] = "rsa_sg58_far_metric_magazine_20r",
    ["rsa_sa58_fal_metric_magazine_30r"] = "rsa_sg58_far_metric_magazine_30r",
    ["rsa_sa58_fal_metric_magazine_5r"] = "rsa_sg58_far_metric_magazine_5r",
    ["rsa_sa58_fal_metric_polymer_magazine_10r"] = "rsa_sg58_far_metric_polymer_magazine_10r",
    ["rsa_sa58_fal_metric_polymer_magazine_20r"] = "rsa_sg58_far_metric_polymer_magazine_20r",
    ["rsa_sa58_folding_spr_para_stock_body"] = "rsa_sg58_folding_spr_para_stock_body",
    ["rsa_sa58_folding_spr_para_stock_buttpad"] = "rsa_sg58_folding_spr_para_stock_buttpad",
    ["rsa_sa58_folding_spr_para_stock_buttpad_mount"] = "rsa_sg58_folding_spr_para_stock_buttpad_mount",
    ["rsa_sa58_folding_spr_para_stock_cheek_riser"] = "rsa_sg58_folding_spr_para_stock_cheek_riser",
    ["rsa_sa58_folding_spr_para_stock_extendable_part"] = "rsa_sg58_folding_spr_para_stock_extendable_part",
    ["rsa_sa58_holland_type_sight"] = "rsa_sg58_holland_type_sight",
    ["rsa_sa58_mag_bottom_plate"] = "rsa_sg58_mag_bottom_plate",
    ["rsa_sa58_metric_mlok_full_length_bottom_handguard"] = "rsa_sg58_metric_mlok_full_length_bottom_handguard",
    ["rsa_sa58_metric_mlok_full_length_top_handguard"] = "rsa_sg58_metric_mlok_full_length_top_handguard",
    ["rsa_sa58_metric_mlok_mid_length_bottom_handguard"] = "rsa_sg58_metric_mlok_mid_length_bottom_handguard",
    ["rsa_sa58_metric_mlok_mid_length_top_handguard"] = "rsa_sg58_metric_mlok_mid_length_top_handguard",
    ["rsa_sa58_metric_mlok_pistol_length_bottom_handguard"] = "rsa_sg58_metric_mlok_pistol_length_bottom_handguard",
    ["rsa_sa58_metric_mlok_pistol_length_top_handguard"] = "rsa_sg58_metric_mlok_pistol_length_top_handguard",
    ["rsa_sa58_metric_para_folding_stock"] = "rsa_sg58_metric_para_folding_stock",
    ["rsa_sa58_para_fold_assembly"] = "rsa_sg58_para_fold_assembly",
    ["rsa_sa58_para_rear_sight"] = "rsa_sg58_para_rear_sight",
    ["rsa_sa58_pistol_gas_piston"] = "rsa_sg58_pistol_gas_piston",
    ["rsa_sa58_pistol_qd_sling_endplate"] = "rsa_sg58_pistol_qd_sling_endplate",
    ["rsa_sa58_polymer_humpback_stock"] = "rsa_sg58_polymer_humpback_stock",
    ["rsa_sa58_rear_sight_picatinny_mount"] = "rsa_sg58_rear_sight_picatinny_mount",
    ["rsa_sa58_rifle_gas_piston"] = "rsa_sg58_rifle_gas_piston",
    ["rsa_sa58_tactical_pistol_v2_handguard"] = "rsa_sg58_tactical_pistol_v2_handguard",
    ["rsa_sa58_wood_full_length_handguard"] = "rsa_sg58_wood_full_length_handguard",
    ["rsa_sa58_wood_humpback_stock"] = "rsa_sg58_wood_humpback_stock",
    ["rsa_sa58_x_series_stock"] = "rsa_sg58_x_series_stock",
    ["sa58_std_charging_handle"] = "sg58_std_charging_handle",
    ["sa58_std_fire_selector"] = "sg58_std_fire_selector",
    ["sa58_std_grip"] = "sg58_std_grip",
    ["sa58_std_lower_receiver"] = "sg58_std_lower_receiver",
    ["sa58_stg58_carry_handle"] = "sg58_stg58_carry_handle",
    ["sa58_type1_upper_receiver"] = "sg58_type1_upper_receiver",
    ["sa58_type1_upper_receiver_with_carry_handle"] = "sg58_type1_upper_receiver_with_carry_handle",
    ["sa58_wood_stock_buttpad"] = "sg58_wood_stock_buttpad",
    ["sig_sauer_romeo4b_sight"] = "sic_sturmer_scipio4b_sight",
    ["sig_sauer_romeo4t_sight"] = "sic_sturmer_scipio4t_sight",
    ["sig_sauer_romeo5_1x20_sight"] = "sic_sturmer_scipio5_sight",
    ["sig_sauer_romeo5_low_mount"] = "sic_sturmer_scipio5_low_mount",
    ["steyr_aug_a1_stg77_1_5x_scoped_receiver"] = "lowenherz_aug_a1_stg77_1_5x_scoped_receiver",
    ["steyr_aug_a3_austrian_stock"] = "lowenherz_aug_a3_austrian_stock",
    ["steyr_aug_a3_m1_receiver"] = "lowenherz_aug_a3_m1_receiver",
    ["steyr_aug_a3_nato_stock"] = "lowenherz_aug_a3_nato_stock",
    ["steyr_aug_a3_para_9x19_stock"] = "lowenherz_aug_a3_para_9x19_stock",
    ["steyr_aug_a3_sa_receiver"] = "lowenherz_aug_a3_sa_receiver",
    ["steyr_breezer_ums_5.56x45_aug_suppressor"] = "lowenherz_breezer_ums_5.56x45_aug_suppressor",
    ["swampfox_picatinny_rmr_footprint_mount"] = "swampfox_picatinny_drd_footprint_mount",
    ["troy_battlesight_picatinny_base"] = "talvern_battlesight_picatinny_base",
    ["troy_battlesight_round_aperture"] = "talvern_battlesight_round_aperture",
    ["troy_battlesight_round_aperture_for_folded"] = "talvern_battlesight_round_aperture_for_folded",
    ["troy_battlesight_std_front_post"] = "talvern_battlesight_std_front_post",
    ["troy_claymore556"] = "talvern_claymore_5.56x45_muzzle_brake",
    ["troy_enhanced_ar15_trigger_guard"] = "talvern_enhanced_ar15_trigger_guard",
    ["troy_front_hk_battlesight"] = "talvern_front_hk_battlesight",
    ["troy_front_hk_battlesight_folded"] = "talvern_front_hk_battlesight_folded",
    ["troy_m7a1_pdw_ar15_bcg"] = "talvern_m7a1_pdw_ar15_bcg",
    ["troy_m7a1_pdw_base_stock"] = "talvern_m7a1_pdw_base_stock",
    ["troy_m7a1_pdw_extendable_stock"] = "talvern_m7a1_pdw_extendable_stock",
    ["troy_rear_battlesight"] = "talvern_rear_battlesight",
    ["troy_rear_battlesight_folded"] = "talvern_rear_battlesight_folded",
    ["tyler_freelance_hart_smg_10r_mag_extension"] = "dante_freelance_hart_smg_10r_mag_extension",
    ["unity_fast_lpvo_30mm_mount"] = "harmony_fast_lpvo_30mm_mount",
    ["unity_fast_micro_mount"] = "harmony_fast_micro_mount",
    ["unity_fast_offset_optic_base"] = "harmony_fast_offset_optic_base",
    ["unity_fast_optics_riser"] = "harmony_fast_optics_riser",
    ["unity_offset_optic_rmr_adapter_plate"] = "harmony_offset_optic_rmr_adapter_plate",
    ["vallais_smr_mk16_mlok_urg_i_10.5inch"] = "vallais_mfh_mk16_mlok_urgi_10.5inch",
    ["vallais_smr_mk16_mlok_urg_i_13.5inch"] = "vallais_mfh_mk16_mlok_urgi_13.5inch",
    ["vallais_smr_mk16_mlok_urg_i_15inch"] = "vallais_mfh_mk16_mlok_urgi_15inch",
    ["vallais_smr_mk16_mlok_urg_i_9.3inch"] = "vallais_mfh_mk16_mlok_urgi_9.3inch",
    ["vallais_smr_mk4_federal_mlok_10inch"] = "vallais_mfh_mk4_federal_mlok_10inch",
    ["vector_45acp_140mm_barrel"] = "kalis_scalar_140mm_45acp_threaded_barrel",
    ["vector_45acp_170mm_barrel"] = "kalis_scalar_165mm_45acp_threaded_barrel",
    ["vector_45acp_bolt"] = "kalis_scalar_std_bcg",
    ["vector_45acp_upper_receiver"] = "kalis_scalar_gen2_early_45acp_upper_receiver",
    ["vector_9mm_140mm_barrel"] = "kalis_scalar_140mm_9x19_threaded_barrel",
    ["vector_9mm_170mm_barrel"] = "kalis_scalar_165mm_9x19_threaded_barrel",
    ["vector_9mm_bolt"] = "kalis_scalar_std_bcg",
    ["vector_9mm_upper_receiver"] = "kalis_scalar_gen2_early_9x19_upper_receiver",
    ["vector_bolt_release"] = "kalis_scalar_std_bolt_catch",
    ["vector_bottom_rail"] = "kalis_scalar_gen2_receiver_bottom_rail",
    ["vector_charging_handle"] = "kalis_scalar_std_charging_handle",
    ["vector_left_rail"] = "kalis_scalar_7_slot_left_side_rail",
    ["vector_lower_receiver"] = "kalis_scalar_gen1_45acp_lower_receiver",
    ["vector_mk1_modular_rail"] = "kalis_scalar_mk1_handguard",
    ["vector_mk5_mlok_rail"] = "kalis_scalar_mk5_handguard",
    ["vector_mk5_side_rail"] = "kalis_scalar_mk5_handguard_bottom_rail",
    ["vector_right_rail"] = "kalis_scalar_7_slot_misc_rail",
    ["vector_round_shroud_mk1_11inch_modular"] = "kalis_scalar_mk11_handguard",
    ["vector_round_shroud_mk1_9inch_modular"] = "kalis_scalar_mk9_handguard",
    ["vector_std_mag_eject"] = "kalis_scalar_std_mag_release",
    ["vector_std_trigger"] = "kalis_scalar_gen1_trigger",
    ["virticon_acog_ta01_4x_scope"] = "virticon_arcs_ta01_4x_scope",
    ["virticon_acog_ta01_4x_scope_carry_handle"] = "virticon_arcs_ta01_4x_scope_carry_handle",
    ["virticon_acog_ta11d_bac"] = "virticon_arcs_ta11d_bac",
    ["virticon_acog_ta11d_bac_carry_handle"] = "virticon_arcs_ta11d_bac_carry_handle",
    ["virticon_acog_ta31_comspec_4x_scope"] = "virticon_arcs_ta31_comspec_4x_scope",
    ["virticon_acog_ta31_comspec_4x_scope_carry_handle"] = "virticon_arcs_ta31_comspec_4x_scope_carry_handle",
    ["virticon_acog_ta31_milspec_4x_scope"] = "virticon_arcs_ta31_milspec_4x_scope",
    ["virticon_acog_ta31_milspec_4x_scope_carry_handle"] = "virticon_arcs_ta31_milspec_4x_scope_carry_handle",
    ["virticon_compact_acog_3x24_ta50c_green"] = "virticon_compact_arcs_3x24_ta50c_green",
    ["virticon_compact_acog_3x24_ta50c_red"] = "virticon_compact_arcs_3x24_ta50c_red",
    ["virticon_compact_acog_ac12041_mount"] = "virticon_compact_arcs_ac12041_mount",
    ["virticon_rm33_mount"] = "virticon_dr33_mount",
    ["virticon_rm34_ac12036_mount"] = "virticon_dr34_ac12036_mount",
    ["virticon_rm34_rmr_adapter"] = "virticon_dr34_rmr_adapter",
    ["virticon_rm35_acog_mount"] = "virticon_rm35_arcs_mount",
    ["virticon_rmr_rm01_type2_auto_led_reflex"] = "virticon_drd_dr01_type2_auto_led_reflex",
    ["virticon_rmr_rm05_dual_illuminated_reflex"] = "virticon_drd_dr05_dual_illuminated_reflex",
    ["virticon_rmr_rm06_type2_adj_led_reflex"] = "virticon_drd_dr06_type2_adj_led_reflex",
    ["virticon_sro_reflex_sight"] = "virticon_cro_reflex_sight",
    ["virticon_srs02"] = "virticon_sps02",
    ["whitehouse_compm_30mm_mount"] = "whitehouse_duty_30mm_mount",
    ["whitner_defense_true_zero_acro_mount"] = "whitner_defense_true_zero_ecro_mount",
}
-- END ATTACHMENT_ALIASES

-- Follows the alias chain to the current id (cycle-safe).
local function resolve_attachment_id(att_id)
    local seen = {}
    local current = att_id
    while ATTACHMENT_ALIASES[current] and not seen[current] do
        seen[current] = true
        current = ATTACHMENT_ALIASES[current]
    end
    return current
end

local WEAPON_ALIASES = {
    HK416A5 = "KF416",
    AK74N   = "AK_545",
    AKMN    = "AK_762",
    PP19    = "AK_9",
    UMP45   = "UMP",
    Glock17 = "KOSCH",
    Glock20 = "KOSCH",
}

local WEAPON_DISPLAY_NAMES = {
    SCARH             = "SCAR-H",
    AK_762            = "AKM",
    AUG_A3            = "AUG A3",
    Remington700      = "R700",
    SCAR47            = "SCAR-47",
    AK_545            = "AK-74",
    AK308             = "AK-308",
    SCARL             = "SCAR-L",
    QBZ95             = "QBZ-95",
    EDC_X9            = "EDC X9",
    AK12              = "AK-12",
    Remington870      = "R870",
    AK_545_Carbine    = "AKS-74U",
    MosinNagant       = "Mosin-Nagant",
    AK_9              = "AK-9",
    KOSCH             = "Kosch",
    M11_EOD           = "M11 EOD",
    MP133             = "MP-133",
    IZHEVSK_AKM_TYPE1 = "AKM Type1",
    IZHEVSK_AKM_TYPE2 = "AKM Type2",
    F1                = "F-1",
    M8HC              = "M8",
    RGD2              = "RGD-2",
    RPG7              = "RPG-7",
    Zarya3            = "Zarya-3",
    PlacingTool       = "Placing Tool",
}

local ATTACHMENT_ACRONYMS = {
    acog    = "ACOG",
    rmr     = "RMR",
    sro     = "SRO",
    eod     = "EOD",
    cqc     = "CQC",
    oem     = "OEM",
    pepr    = "P.E.P.R.",
    spr     = "SPR",
    ddg     = "DDG",
    hdd     = "HDD",
    ap      = "AP",
    fmj     = "FMJ",
    otm     = "OTM",
    hp      = "HP",
    jsp     = "JSP",
    ps      = "PS",
    sat     = "SAT",
    mvg     = "MVG",
    afg     = "AFG",
    lss     = "LSS",
    nv      = "NV",
    ir      = "IR",
    rsb     = "RSB",
    vg      = "VG",
    pt      = "PT",
    fcu     = "FCU",
    fsp     = "FSP",
    raf     = "RAF",
    tac     = "TAC",
    sdmr    = "SDMR",
    bdc     = "BDC",
    srx     = "SRX",
    urgi    = "URG-I",
    akm     = "AKM",
    ak74    = "AK-74",
    ak74m   = "AK-74M",
    ak12    = "AK-12",
    ak308   = "AK-308",
    ak      = "AK",
    ar15    = "AR-15",
    ar9     = "AR-9",
    m4      = "M4",
    m4a1    = "M4A1",
    m16     = "M16",
    fal     = "FAL",
    sa58    = "SA58",
    g3      = "G3",
    scar    = "SCAR",
    scarh   = "SCAR-H",
    scarl   = "SCAR-L",
    scar20  = "SCAR-20",
    scar47  = "SCAR-47",
    mp5     = "MP5",
    mp5k    = "MP5K",
    aug     = "AUG",
    psg1    = "PSG-1",
    hk      = "HK",
    fn      = "FN",
    atg     = "ATG",
    pbs     = "PBS",
    rpk     = "RPK",
    rpk16   = "RPK-16",
    bcg     = "BCG",
    bcm     = "BCM",
    qd      = "QD",
    kag     = "KAG",
    mlok    = "M-LOK",
    pmag    = "PMAG",
    pmm     = "PMM",
    xl      = "XL",
    mre     = "MRE",
    cmmg    = "CMMG",
    aics    = "AICS",
    pdw     = "PDW",
    prs     = "PRS",
    ubr     = "UBR",
    moe     = "MOE",
    moa     = "MOA",
    aft     = "AFT",
    gdr     = "GDR",
    zvn     = "ZVN",
    std     = "Std",
    socom   = "SOCOM",
    gen1    = "Gen 1",
    gen2    = "Gen 2",
    gen3    = "Gen 3",
    gen4    = "Gen 4",
    gen5    = "Gen 5",
    acr     = "ACR",
    sas     = "SAS",
    rsa     = "RSA",
    sig     = "SIG",
    sauer   = "Sauer",
    okp     = "OKP",
    pso     = "PSO",
    pkas    = "PK-AS",
    edc     = "EDC",
    x9      = "X9",
    qbz95   = "QBZ-95",
    m855    = "M855",
    m855a1  = "M855A1",
    m118lr  = "M118LR",
    m993    = "M993",
    m995    = "M995",
    xm193   = "XM193",
    l7awm   = "L7AWM",
}

local item_display_cache = {}

local function get_game_item_display_name(id)
    if item_display_cache[id] then
        return item_display_cache[id]
    end

    local ok, name = pcall(function()
        if not game then return nil end
        local rs = game:GetService("ReplicatedStorage")
        if not rs then return nil end
        local data = rs:FindFirstChild("data")
        local item_folder = data and data:FindFirstChild("item")
        if not item_folder then return nil end
        local obj = item_folder:FindFirstChild(id)
        if not obj then return nil end

        -- Check attributes
        local attr = obj:GetAttribute("display_name")
            or obj:GetAttribute("DisplayName")
            or obj:GetAttribute("title")
        if attr and type(attr) == "string" and #attr > 0 then
            return attr
        end

        -- Check StringValue children
        local val = obj:FindFirstChild("display_name")
            or obj:FindFirstChild("DisplayName")
            or obj:FindFirstChild("title")
        if val and val:IsA("StringValue") and #val.Value > 0 then
            return val.Value
        end

        -- Check ModuleScript return
        if obj:IsA("ModuleScript") then
            local mod = require(obj)
            if type(mod) == "table" then
                local dname = mod.display_name or mod.DisplayName or mod.title or mod.name
                if dname and type(dname) == "string" and #dname > 0 then
                    return dname
                end
            end
        end

        return nil
    end)

    if ok and name then
        item_display_cache[id] = name
        return name
    end
    return nil
end

local function polish_attachment_word(w)
    local low = string.lower(w)
    if ATTACHMENT_ACRONYMS[low] then
        return ATTACHMENT_ACRONYMS[low]
    end
    -- Caliber pattern: 7.62x51, 5.56x45, 9x19, 7.62x54r, 5.8x42, etc.
    if string.match(low, "^%d+%.?%d*x%d+%a*$") then
        return low
    end
    -- Bullet grain: 175gr, 62gr, etc.
    if string.match(low, "^%d+gr$") then
        return low
    end
    -- Magazine capacity: 30r, 20r, 50r -> 30R, 20R, 50R
    if string.match(low, "^%d+r$") then
        return string.upper(low)
    end
    -- Length in millimeters: 406mm, 457mm, etc.
    if string.match(low, "^%d+mm$") then
        return low
    end
    -- Length in inches: 10.5inch, 11.5i, etc.
    local inch_num = string.match(low, "^(%d+%.?%d*)inch$")
    if inch_num then
        return inch_num .. " Inch"
    end
    local i_num = string.match(low, "^(%d+%.?%d*)i$")
    if i_num then
        return i_num .. " Inch"
    end
    -- Alphanumeric model code: a3 -> A3, m1 -> M1, v5 -> V5
    if string.match(low, "^%a%d+%a?$") then
        return string.upper(low)
    end

    -- Title-case hyphenated parts: e.g. "semi-auto" -> "Semi-Auto"
    local parts = {}
    for part in string.gmatch(low, "[^%-]+") do
        local cap = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        table.insert(parts, cap)
    end
    return table.concat(parts, "-")
end

local function polish_attachment_name(tech_id)
    local words = {}
    for w in string.gmatch(tech_id, "[^_]+") do
        table.insert(words, polish_attachment_word(w))
    end
    return table.concat(words, " ")
end

local function resolve_attachment_display_name(canonical_id)
    -- 1. Try querying in-game ReplicatedStorage item definition
    local game_name = get_game_item_display_name(canonical_id)
    if game_name and #game_name > 0 then
        return game_name
    end

    -- 2. Fall back to intelligent heuristic polisher
    return polish_attachment_name(canonical_id)
end

local function resolve_weapon_display_name(raw_gun_id)
    if not raw_gun_id or raw_gun_id == "N/A" then
        return "N/A"
    end
    -- Try in-game item lookup first
    local game_name = get_game_item_display_name(raw_gun_id)
    if game_name and #game_name > 0 then
        return game_name
    end

    local canonical = WEAPON_ALIASES[raw_gun_id] or raw_gun_id
    if WEAPON_DISPLAY_NAMES[canonical] then
        return WEAPON_DISPLAY_NAMES[canonical]
    end
    if WEAPON_DISPLAY_NAMES[raw_gun_id] then
        return WEAPON_DISPLAY_NAMES[raw_gun_id]
    end
    return canonical
end

local function print_attachment_stats(target_player)
    local my_player = target_player
    if not my_player then
        for _, plr in ipairs(players.get_all()) do
            local is_bot = false
            if type(plr.is_bot) == "function" then
                local ok, res = pcall(function() return plr.is_bot() end)
                if ok then
                    is_bot = res
                else
                    local ok2, res2 = pcall(function() return plr:is_bot() end)
                    if ok2 then is_bot = res2 end
                end
            end
            if not is_bot then
                my_player = plr
                break
            end
        end
    end

    if my_player and type(my_player.get_profile_stats) == "function" then
        local stats = my_player.get_profile_stats() or {}
        local weapons_table = stats.weapon or {}

        -- Aggregator: [canonical_id] = { kills = X, weapons = { [gun_id] = kills }, legacy = { [old_id] = true } }
        local attachment_totals = {}
        local legacy_merged = 0 -- distinct legacy ids folded into a canonical id

        for weapon_id, weapon_data in pairs(weapons_table) do
            local att_stats = weapon_data.attachment_stats or {}
            
            for att_id, data in pairs(att_stats) do
                local kills = 0
                if type(data) == "table" then
                    kills = tonumber(data.kills or data.kill_count or 0) or 0
                elseif type(data) == "number" then
                    kills = data
                end

                if kills > 0 then
                    local canonical_id = resolve_attachment_id(att_id)
                    local bucket = attachment_totals[canonical_id]
                    if not bucket then
                        bucket = { kills = 0, weapons = {}, legacy = {} }
                        attachment_totals[canonical_id] = bucket
                    end
                    if canonical_id ~= att_id and not bucket.legacy[att_id] then
                        bucket.legacy[att_id] = true
                        legacy_merged = legacy_merged + 1
                    end
                    bucket.kills = bucket.kills + kills
                    local canonical_gun = WEAPON_ALIASES[weapon_id] or weapon_id
                    bucket.weapons[canonical_gun] = (bucket.weapons[canonical_gun] or 0) + kills
                end
            end
        end

        -- Convert to sorted array
        local sorted = {}
        for att_id, info in pairs(attachment_totals) do
            local top_gun = "N/A"
            local top_gun_kills = 0
            for g_id, g_kills in pairs(info.weapons) do
                -- Ties break toward the lexicographically smallest gun so output is deterministic.
                if g_kills > top_gun_kills or (g_kills == top_gun_kills and g_id < top_gun) then
                    top_gun = g_id
                    top_gun_kills = g_kills
                end
            end

            table.insert(sorted, {
                id = att_id,
                display_name = resolve_attachment_display_name(att_id),
                kills = info.kills,
                top_gun = top_gun,
                top_gun_display = resolve_weapon_display_name(top_gun),
                top_gun_kills = top_gun_kills
            })
        end

        table.sort(sorted, function(a, b)
            if a.kills ~= b.kills then
                return a.kills > b.kills
            end
            return a.display_name < b.display_name
        end)

        -- All attachments found are displayed (no 500 cap)
        local limit = #sorted
        local rank_width = math.max(#tostring(math.max(limit, 1)), 3)
        local name_width = 32
        local kills_width = 6
        local gun_width = #("Top Gun")
        for i = 1, limit do
            local item = sorted[i]
            if #item.display_name > name_width then
                name_width = #item.display_name
            end
            local digits = #tostring(item.kills)
            if digits > kills_width then
                kills_width = digits
            end
            if #item.top_gun_display > gun_width then
                gun_width = #item.top_gun_display
            end
        end

        local function pad_right(text, width)
            text = tostring(text)
            if #text < width then
                return text .. string.rep(" ", width - #text)
            end
            return text
        end

        print(string.format("\n================ ALL %d ATTACHMENTS BY KILLS ================", limit))
        if legacy_merged > 0 then
            print(string.format("-- ALIASES MERGED: %d legacy attachment ids folded into current ids (renames.csv)", legacy_merged))
        end

        if limit == 0 then
            print("No attachment kills found across any weapons.")
        else
            print("Total Unique Attachments Found: " .. #sorted)
            print("Displaying all " .. limit .. " attachments...\n")

            -- Batch printing to avoid console buffer overflow
            for i = 1, limit do
                local item = sorted[i]
                print("#" .. pad_right(tostring(i), rank_width)
                    .. " " .. pad_right(item.display_name, name_width)
                    .. " | Kills: " .. pad_right(tostring(item.kills), kills_width)
                    .. " | Top Gun: " .. pad_right(item.top_gun_display, gun_width)
                    .. " (" .. tostring(item.top_gun_kills) .. ")")

                -- Pause briefly every 50 entries to keep the log rendering cleanly
                if i % 50 == 0 and task and task.wait then
                    task.wait(0.05)
                end
            end
        end
        print("==============================================================")
        return sorted
    else
        print("Could not retrieve player profile stats.")
    end
end

-- Persist in shared environment for subsequent console executions
shared.print_attachment_stats = print_attachment_stats

-- Run immediately on execution
print_attachment_stats()

return print_attachment_stats
