-- print_attachment_stats.luau
-- Prints aggregated attachment statistics (kills and top weapon) across all weapons.
-- Displays in-game names instead of backend technical IDs.
-- Displays ALL attachments found (no truncation).
-- Legacy attachment ids are folded into their current ids via ATTACHMENT_ALIASES
-- (snapshot of deadline-balancing renames.csv), so renamed or merged parts
-- (e.g. both Vector bolts -> kalis_scalar_std_bcg) report unified totals.
--
-- How to call in the Luau Server Console:
--   1. Paste the script contents or run:
--        require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_attachment_stats.luau")
--   2. For subsequent calls in the same server session:
--        shared.print_attachment_stats()                      -- default (first human player)
--        shared.print_attachment_stats(players.get("Name"))   -- specific player
--
-- Keep every function (including this file's top level) within 255 source lines;
-- Deadline's Fiu VM fails to load anything longer. Run tools/check_fiu_compat.py.

-- Display names are downloaded from modules/attachment_names.luau, which is
-- regenerated from recoil-group/deadline-balancing balancing.csv. Ids it does not
-- know yet (brand-new attachments) print as a prettified id. Set LOAD_NAMES to
-- false to skip the download.
local LOAD_NAMES = true
local NAMES_URL = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/attachment_names.luau"

-- BEGIN ATTACHMENT_ALIASES (generated from deadline-balancing renames.csv - do not edit by hand; use build_attachment_aliases.py)
local ATTACHMENT_ALIASES = {
    ["45acp_kriss_magex2_pf940"] = "kalis_kosch_45acp_17r_magex2", ["5.56x45_winchester_m855_62gr_fmj"] = "5.56x45_appalachian_m855_62gr_fmj", ["5.8x42_sanxian_dfv18_76gr_hp"] = "5.8x42_sanxian_dvf18_76gr_hp", ["7.62x54r_norilsk_7t2_149gr_green_tracer"] = "7.62x54r_norilsk_7t2m_149gr_green_tracer", ["7.62x54r_zim_rifle_150gr_spbt"] = "7.62x54r_pga_rifle_150gr_spbt", ["9x18_norilsk_57t181_56gr_red_tracer"] = "9x18_novosibirsk_57_t_181_56gr_red_tracer", ["9x19_ammocor_usa_147gr_subsonic"] = "9x19_zfm_luger_154gr_fmjfp_subsonic", ["9x19_kriss_magex2_glock"] = "kalis_kosch_9x19_23r_magex2", ["9x19_pf940_std_17r_vector"] = "kosch_9x19_17r_magazine", ["9x19_sgmt_drum50r_vector"] = "fst_kosch_9x19_50r_drum_magazine", ["9x19_traviata_mle_94gr_rht_frangible"] = "9x19_appalachian_mk254_mod0_90gr_frangible",
    ["9x19_winchester_m822_124gr_fmj"] = "9x19_appalachian_m882_124gr_fmj", ["aeroknox_ae01_muzzle_brake"] = "equinox_ae01_muzzle_brake", ["aeroknox_ax15_10.5inch_handguard"] = "equinox_ex15_10.5inch_handguard", ["aeroknox_ax15_endplate"] = "equinox_ex15_endplate", ["aeroknox_ax15_front_sight"] = "equinox_ex15_front_sight", ["aeroknox_ax15_front_sight_base"] = "equinox_ex15_front_sight_base", ["aeroknox_ax15_front_sight_folded"] = "equinox_ex15_front_sight_folded", ["aeroknox_ax15_lower_receiver"] = "equinox_ex15_lower_receiver", ["aeroknox_ax15_lower_receiver_ar9"] = "equinox_ex15_lower_receiver_ar9", ["aeroknox_ax15_orion_pistol_grip"] = "equinox_ex15_orion_pistol_grip", ["aeroknox_ax15_rear_sight"] = "equinox_ex15_rear_sight",
    ["aeroknox_ax15_rear_sight_base"] = "equinox_ex15_rear_sight_base", ["aeroknox_ax15_rear_sight_folded"] = "equinox_ex15_rear_sight_folded", ["aeroknox_ax15_upper_receiver"] = "equinox_ex15_upper_receiver", ["aeroknox_ax_mlok_cover"] = "equinox_ex_mlok_cover", ["aeroknox_ax_mlok_cover_flipped"] = "equinox_ex_mlok_cover_flipped", ["aeroknox_ax_mlok_grip"] = "equinox_ex_mlok_grip", ["aeroknox_ax_mp5_modified_trigger_housing"] = "equinox_ex_mp5_modified_trigger_housing", ["aeroknox_ax_mp5_trigger_housing"] = "equinox_ex_mp5_trigger_housing", ["aeroknox_plus_5_pmag_mag_extension"] = "equinox_plus_5_pmag_mag_extension", ["azimuth_acro_kosch_adapter_plate"] = "azimuth_ecro_kosch_adapter_plate", ["azimuth_acro_p2_reflex_sight"] = "azimuth_ecro_p2_reflex_sight",
    ["azimuth_compm2_sight"] = "azimuth_duty2_sight", ["azimuth_compm4_sight"] = "azimuth_duty4_sight", ["azimuth_compm5_lens_caps"] = "azimuth_duty5_lens_caps", ["azimuth_compm5_sight"] = "azimuth_duty5_sight", ["bcm_gunfighter_kag"] = "ecm_gunslinger_kag", ["bcm_gunfighter_mod3_ar15_pistol_grip"] = "ecm_gunslinger_mod3_ar15_pistol_grip", ["bcm_gunfighter_mod3_mlok_foregrip"] = "ecm_gunslinger_mod3_mlok_foregrip", ["bcm_gunfighter_mod3_mlok_foregrip_flipped"] = "ecm_gunslinger_mod3_mlok_foregrip_flipped", ["bcm_gunfighter_mod3_mlok_shortened_foregrip"] = "ecm_gunslinger_mod3_mlok_shortened_foregrip", ["bcm_gunfighter_mod3_mlok_shortened_foregrip_flipped"] = "ecm_gunslinger_mod3_mlok_shortened_foregrip_flipped", ["bcm_gunfighter_mod3_picatinny_foregrip"] = "ecm_gunslinger_mod3_picatinny_foregrip",
    ["bcm_gunfighter_mod3_picatinny_foregrip_flipped"] = "ecm_gunslinger_mod3_picatinny_foregrip_flipped", ["bcm_gunfighter_mod3_picatinny_shortened_foregrip"] = "ecm_gunslinger_mod3_picatinny_shortened_foregrip", ["bcm_gunfighter_mod3_picatinny_shortened_foregrip_flipped"] = "ecm_gunslinger_mod3_picatinny_shortened_foregrip_flipped", ["bravo_comp_gunfighter_charging_handle"] = "ecm_gunslinger_charging_handle", ["bt_qd_nar_acro_22mm_mount"] = "bt_qd_nar_ecro_22mm_mount", ["bt_qd_nar_acro_30mm_mount"] = "bt_qd_nar_ecro_30mm_mount", ["bt_qd_nar_acro_39mm_mount"] = "bt_qd_nar_ecro_39mm_mount", ["cartesia_productions_x_fal_drum_mag_50r"] = "cartesia_productions_x_far_drum_mag_50r", ["corvus_defensio_aug_a3_mlok_top_rail"] = "aquila_defensio_aug_a3_mlok_top_rail", ["corvus_defensio_aug_case_deflector"] = "aquila_defensio_aug_case_deflector", ["corvus_defensio_aug_charging_handle"] = "aquila_defensio_aug_charging_handle",
    ["corvus_defensio_aug_enhanced_release_button"] = "aquila_defensio_aug_enhanced_release_button", ["corvus_defensio_aug_forward_accessory_rail"] = "aquila_defensio_aug_forward_accessory_rail", ["corvus_defension_m1_aug_receiver_rail"] = "aquila_defension_m1_aug_receiver_rail", ["dd_enhanced_mvg"] = "ad_enhanced_mvg", ["dd_mk18_fsp_ris_2_9.55_handguard"] = "ad_mk18_fsp_raf_2_9.55_handguard", ["fn_fal_7.62x51_belgian_flash_hider"] = "af_far_7.62x51_belgian_flash_hider", ["fn_fal_austrian_7.62x51_stg58_flash_hider"] = "af_far_austrian_7.62x51_stg58_flash_hider", ["fn_fal_long_carry_handle"] = "af_far_long_carry_handle", ["fn_fal_std_dust_cover"] = "af_far_std_dust_cover", ["fnb_precision_fal_crosshair_front_sight"] = "fnb_precision_far_crosshair_front_sight", ["fnb_precision_fal_duplex_front_sight"] = "fnb_precision_far_duplex_front_sight",
    ["glock17_auto_sear"] = "kosch_metal_auto_sear", ["glock17_gen5_mag_release"] = "kosch_default_mag_release", ["glock17_gen5_trigger_safety"] = "kosch_default_trigger_safety", ["glock17_slide_backplate"] = "kosch_default_slide_backplate", ["glock17_std_mag_bottom_plate"] = "kosch_default_small_mag_plate", ["glock20_std_mag_bottom_plate"] = "kosch_default_large_mag_plate", ["holosun_he510c-gr_sight"] = "holostar_hx510c_gr_reflex", ["holosun_hs510c_sight"] = "holostar_hx510c_reflex", ["holotec_ogl_lens_caps"] = "holotec_owl_lens_caps", ["kosch_default_10mm_mag_plate"] = "kosch_default_large_mag_plate", ["kosch_default_9x19_mag_plate"] = "kosch_default_small_mag_plate",
    ["kriss_vector_gen2_folding_stock"] = "kalis_scalar_gen1_fsbl00_hinged_folding_stock", ["kriss_vector_non_folding_stock_adapter"] = "kalis_scalar_gen1_sabl00_hinged_buffer_tube_adapter", ["lowenhurz_aug_hbar_620mm_heavy_barrel"] = "lowenherz_aug_hbar_620mm_heavy_barrel", ["lowenhurz_aug_hbar_folding_bipod"] = "lowenherz_aug_hbar_folding_bipod", ["magtap_moe_a_frame_fixed_ak_stock"] = "magtap_moa_a_frame_fixed_ak_stock", ["magtap_moe_a_frame_stock_buttpad"] = "magtap_moa_a_frame_stock_buttpad", ["magtap_moe_ar15_pistol_grip"] = "magtap_moa_ar15_pistol_grip", ["magtap_moe_butt_pad"] = "magtap_moa_butt_pad", ["magtap_moe_carbine_stock"] = "magtap_moa_carbine_stock", ["magtap_moe_k2_ak_pistol_grip"] = "magtap_moa_k2_ak_pistol_grip", ["magtap_moe_k2_ar15_pistol_grip"] = "magtap_moa_k2_ar15_pistol_grip",
    ["magtap_moe_k2_scar_pistol_grip"] = "magtap_moa_k2_scar_pistol_grip", ["magtap_moe_scar_pistol_grip"] = "magtap_moa_scar_pistol_grip", ["magtap_moe_sl_k_carbine_stock"] = "magtap_moa_sl_k_carbine_stock", ["magtap_moe_sl_k_carbine_stock_buttpad"] = "magtap_moa_sl_k_carbine_stock_buttpad", ["mcs_tac21_gen2_15inch_r700_mlok_handguard"] = "mcs_rev21_gen2_15inch_r700_mlok_handguard", ["mcs_tac21_gen2_r700_lower_receiver"] = "mcs_rev21_gen2_r700_lower_receiver", ["nm_fal_polymer_mag_20r"] = "nm_far_polymer_mag_20r", ["nowa_gen3_ar15_upper_receiver"] = "novacek_gen3_ar15_upper_receiver", ["nowa_love_ar15_charging_handle"] = "novacek_love_ar15_charging_handle", ["nowa_marked_vyctor_mur1s_ar15_upper_receiver"] = "novacek_marked_vyctor_mur1s_ar15_upper_receiver", ["nowa_n4_gen3_ar15_lower_receiver"] = "novacek_n4_gen3_ar15_lower_receiver",
    ["nowa_n4_gen3_ar15_lower_receiver_ar9"] = "novacek_n4_gen3_ar15_lower_receiver_ar9", ["nowa_n4_nsr_gen3_handguard_9.15inch"] = "novacek_n4_nsr_gen3_handguard_9.15inch", ["pf940_9x19_stick_31r_magazine"] = "kosch_9x19_31r_stick_magazine", ["pf940_std_13r_vector_remodel"] = "kosch_45acp_13r_magazine", ["pmm_bcm_gunfighter_mod3_scar_pistol_grip"] = "pww_ecm_gunslinger_mod3_scar_pistol_grip", ["primary_arms_slx_1.53inch_straight_spacer_alt"] = "paramount_arms_slx_1.53inch_straight_spacer_alt", ["primary_arms_slx_1x_microprism_acss_g2_scope_alt"] = "paramount_arms_slx_1x_microprism_acss_g2_scope_alt", ["protac_ergonomic_ag_fal_pistol_grip"] = "protac_ergonomic_ag_far_pistol_grip", ["radian_weapons_glock17_afterburner_micro_compensator"] = "ardian_weapons_glock17_afterburner_micro_compensator", ["radian_weapons_glock17_ramjet_barrel"] = "ardian_weapons_glock17_ramjet_barrel", ["romeo4t_folded_lens_caps"] = "scipio4t_folded_lens_caps",
    ["romeo4t_lens_caps"] = "scipio4t_lens_caps", ["rsa_sa58_210mm_premium_pistol_barrel"] = "rsa_sg58_210mm_premium_pistol_barrel", ["rsa_sa58_305mm_barrel"] = "rsa_sg58_305mm_barrel", ["rsa_sa58_330mm_barrel"] = "rsa_sg58_330mm_barrel", ["rsa_sa58_406mm_barrel"] = "rsa_sg58_406mm_barrel", ["rsa_sa58_406mm_fluted_barrel"] = "rsa_sg58_406mm_fluted_barrel", ["rsa_sa58_457mm_barrel"] = "rsa_sg58_457mm_barrel", ["rsa_sa58_533mm_barrel"] = "rsa_sg58_533mm_barrel", ["rsa_sa58_7.62x51_bolt"] = "rsa_sg58_7.62x51_bolt", ["rsa_sa58_belgian_style_full_length_handguard"] = "rsa_sg58_belgian_style_full_length_handguard", ["rsa_sa58_belgian_style_mid_length_handguard"] = "rsa_sg58_belgian_style_mid_length_handguard",
    ["rsa_sa58_buttpad"] = "rsa_sg58_buttpad", ["rsa_sa58_enhanced_bumper_magazine_bottom_plate"] = "rsa_sg58_enhanced_bumper_magazine_bottom_plate", ["rsa_sa58_fal_metric_magazine_10r"] = "rsa_sg58_far_metric_magazine_10r", ["rsa_sa58_fal_metric_magazine_20r"] = "rsa_sg58_far_metric_magazine_20r", ["rsa_sa58_fal_metric_magazine_30r"] = "rsa_sg58_far_metric_magazine_30r", ["rsa_sa58_fal_metric_magazine_5r"] = "rsa_sg58_far_metric_magazine_5r", ["rsa_sa58_fal_metric_polymer_magazine_10r"] = "rsa_sg58_far_metric_polymer_magazine_10r", ["rsa_sa58_fal_metric_polymer_magazine_20r"] = "rsa_sg58_far_metric_polymer_magazine_20r", ["rsa_sa58_folding_spr_para_stock_body"] = "rsa_sg58_folding_spr_para_stock_body", ["rsa_sa58_folding_spr_para_stock_buttpad"] = "rsa_sg58_folding_spr_para_stock_buttpad", ["rsa_sa58_folding_spr_para_stock_buttpad_mount"] = "rsa_sg58_folding_spr_para_stock_buttpad_mount",
    ["rsa_sa58_folding_spr_para_stock_cheek_riser"] = "rsa_sg58_folding_spr_para_stock_cheek_riser", ["rsa_sa58_folding_spr_para_stock_extendable_part"] = "rsa_sg58_folding_spr_para_stock_extendable_part", ["rsa_sa58_holland_type_sight"] = "rsa_sg58_holland_type_sight", ["rsa_sa58_mag_bottom_plate"] = "rsa_sg58_mag_bottom_plate", ["rsa_sa58_metric_mlok_full_length_bottom_handguard"] = "rsa_sg58_metric_mlok_full_length_bottom_handguard", ["rsa_sa58_metric_mlok_full_length_top_handguard"] = "rsa_sg58_metric_mlok_full_length_top_handguard", ["rsa_sa58_metric_mlok_mid_length_bottom_handguard"] = "rsa_sg58_metric_mlok_mid_length_bottom_handguard", ["rsa_sa58_metric_mlok_mid_length_top_handguard"] = "rsa_sg58_metric_mlok_mid_length_top_handguard", ["rsa_sa58_metric_mlok_pistol_length_bottom_handguard"] = "rsa_sg58_metric_mlok_pistol_length_bottom_handguard", ["rsa_sa58_metric_mlok_pistol_length_top_handguard"] = "rsa_sg58_metric_mlok_pistol_length_top_handguard", ["rsa_sa58_metric_para_folding_stock"] = "rsa_sg58_metric_para_folding_stock",
    ["rsa_sa58_para_fold_assembly"] = "rsa_sg58_para_fold_assembly", ["rsa_sa58_para_rear_sight"] = "rsa_sg58_para_rear_sight", ["rsa_sa58_pistol_gas_piston"] = "rsa_sg58_pistol_gas_piston", ["rsa_sa58_pistol_qd_sling_endplate"] = "rsa_sg58_pistol_qd_sling_endplate", ["rsa_sa58_polymer_humpback_stock"] = "rsa_sg58_polymer_humpback_stock", ["rsa_sa58_rear_sight_picatinny_mount"] = "rsa_sg58_rear_sight_picatinny_mount", ["rsa_sa58_rifle_gas_piston"] = "rsa_sg58_rifle_gas_piston", ["rsa_sa58_tactical_pistol_v2_handguard"] = "rsa_sg58_tactical_pistol_v2_handguard", ["rsa_sa58_wood_full_length_handguard"] = "rsa_sg58_wood_full_length_handguard", ["rsa_sa58_wood_humpback_stock"] = "rsa_sg58_wood_humpback_stock", ["rsa_sa58_x_series_stock"] = "rsa_sg58_x_series_stock",
    ["sa58_std_charging_handle"] = "sg58_std_charging_handle", ["sa58_std_fire_selector"] = "sg58_std_fire_selector", ["sa58_std_grip"] = "sg58_std_grip", ["sa58_std_lower_receiver"] = "sg58_std_lower_receiver", ["sa58_stg58_carry_handle"] = "sg58_stg58_carry_handle", ["sa58_type1_upper_receiver"] = "sg58_type1_upper_receiver", ["sa58_type1_upper_receiver_with_carry_handle"] = "sg58_type1_upper_receiver_with_carry_handle", ["sa58_wood_stock_buttpad"] = "sg58_wood_stock_buttpad", ["schmidt_smr_mk16_mlok_urg_i_10.5inch"] = "vallais_mfh_mk16_mlok_urgi_10.5inch", ["schmidt_smr_mk16_mlok_urg_i_13.5inch"] = "vallais_mfh_mk16_mlok_urgi_13.5inch", ["schmidt_smr_mk16_mlok_urg_i_15inch"] = "vallais_mfh_mk16_mlok_urgi_15inch",
    ["schmidt_smr_mk16_mlok_urg_i_9.3inch"] = "vallais_mfh_mk16_mlok_urgi_9.3inch", ["schmidt_super_scar_trigger"] = "vallais_super_fang_trigger", ["schneider_defense_qbz95_long_bow_mlok_carry_handle"] = "qingyuan_defense_qbz95_long_bow_mlok_carry_handle", ["schneider_defense_qbz95_long_bow_picatinny_carry_handle"] = "qingyuan_defense_qbz95_long_bow_picatinny_carry_handle", ["sgm_tactical_pf940_9x19_50r_drum_magazine"] = "fst_kosch_9x19_50r_drum_magazine", ["sig_sauer_romeo4b_sight"] = "sic_sturmer_scipio4b_sight", ["sig_sauer_romeo4t_sight"] = "sic_sturmer_scipio4t_sight", ["sig_sauer_romeo5_1x20_sight"] = "sic_sturmer_scipio5_sight", ["sig_sauer_romeo5_low_mount"] = "sic_sturmer_scipio5_low_mount", ["steyr_aug_a1_stg77_1_5x_scoped_receiver"] = "lowenherz_aug_a1_stg77_1_5x_scoped_receiver", ["steyr_aug_a3_austrian_stock"] = "lowenherz_aug_a3_austrian_stock",
    ["steyr_aug_a3_m1_receiver"] = "lowenherz_aug_a3_m1_receiver", ["steyr_aug_a3_nato_stock"] = "lowenherz_aug_a3_nato_stock", ["steyr_aug_a3_para_9x19_stock"] = "lowenherz_aug_a3_para_9x19_stock", ["steyr_aug_a3_sa_receiver"] = "lowenherz_aug_a3_sa_receiver", ["steyr_aug_hbar_620mm_heavy_barrel"] = "lowenherz_aug_hbar_620mm_heavy_barrel", ["steyr_breezer_ums_5.56x45_aug_suppressor"] = "lowenherz_breezer_ums_5.56x45_aug_suppressor", ["swampfox_picatinny_rmr_footprint_mount"] = "swampfox_picatinny_drd_footprint_mount", ["troy_battlesight_picatinny_base"] = "talvern_battlesight_picatinny_base", ["troy_battlesight_round_aperture"] = "talvern_battlesight_round_aperture", ["troy_battlesight_round_aperture_for_folded"] = "talvern_battlesight_round_aperture_for_folded", ["troy_battlesight_std_front_post"] = "talvern_battlesight_std_front_post",
    ["troy_claymore556"] = "talvern_claymore_5.56x45_muzzle_brake", ["troy_enhanced_ar15_trigger_guard"] = "talvern_enhanced_ar15_trigger_guard", ["troy_front_hk_battlesight"] = "talvern_front_hk_battlesight", ["troy_front_hk_battlesight_folded"] = "talvern_front_hk_battlesight_folded", ["troy_m7a1_pdw_ar15_bcg"] = "talvern_m7a1_pdw_ar15_bcg", ["troy_m7a1_pdw_base_stock"] = "talvern_m7a1_pdw_base_stock", ["troy_m7a1_pdw_extendable_stock"] = "talvern_m7a1_pdw_extendable_stock", ["troy_rear_battlesight"] = "talvern_rear_battlesight", ["troy_rear_battlesight_folded"] = "talvern_rear_battlesight_folded", ["tyler_freelance_hart_smg_10r_mag_extension"] = "dante_freelance_hart_smg_10r_mag_extension", ["um_tactical_um_3_mount"] = "whitner_defense_um3_mount",
    ["unity_fast_lpvo_30mm_mount"] = "harmony_fast_lpvo_30mm_mount", ["unity_fast_micro_mount"] = "harmony_fast_micro_mount", ["unity_fast_offset_optic_base"] = "harmony_fast_offset_optic_base", ["unity_fast_optics_riser"] = "harmony_fast_optics_riser", ["unity_offset_optic_rmr_adapter_plate"] = "harmony_offset_optic_rmr_adapter_plate", ["vallais_smr_mk16_mlok_urg_i_10.5inch"] = "vallais_mfh_mk16_mlok_urgi_10.5inch", ["vallais_smr_mk16_mlok_urg_i_13.5inch"] = "vallais_mfh_mk16_mlok_urgi_13.5inch", ["vallais_smr_mk16_mlok_urg_i_15inch"] = "vallais_mfh_mk16_mlok_urgi_15inch", ["vallais_smr_mk16_mlok_urg_i_9.3inch"] = "vallais_mfh_mk16_mlok_urgi_9.3inch", ["vallais_smr_mk4_federal_mlok_10inch"] = "vallais_mfh_mk4_federal_mlok_10inch", ["vector_17r_plate"] = "kosch_default_small_mag_plate",
    ["vector_45acp_140mm_barrel"] = "kalis_scalar_140mm_45acp_threaded_barrel", ["vector_45acp_170mm_barrel"] = "kalis_scalar_165mm_45acp_threaded_barrel", ["vector_45acp_bolt"] = "kalis_scalar_std_bcg", ["vector_45acp_upper_receiver"] = "kalis_scalar_gen2_early_45acp_upper_receiver", ["vector_9mm_140mm_barrel"] = "kalis_scalar_140mm_9x19_threaded_barrel", ["vector_9mm_170mm_barrel"] = "kalis_scalar_165mm_9x19_threaded_barrel", ["vector_9mm_bolt"] = "kalis_scalar_std_bcg", ["vector_9mm_upper_receiver"] = "kalis_scalar_gen2_early_9x19_upper_receiver", ["vector_bolt_release"] = "kalis_scalar_std_bolt_catch", ["vector_bottom_rail"] = "kalis_scalar_gen2_receiver_bottom_rail", ["vector_charging_handle"] = "kalis_scalar_std_charging_handle",
    ["vector_left_rail"] = "kalis_scalar_7_slot_left_side_rail", ["vector_lower_receiver"] = "kalis_scalar_gen1_45acp_lower_receiver", ["vector_mk1_modular_rail"] = "kalis_scalar_mk1_handguard", ["vector_mk5_mlok_rail"] = "kalis_scalar_mk5_handguard", ["vector_mk5_side_rail"] = "kalis_scalar_mk5_handguard_bottom_rail", ["vector_right_rail"] = "kalis_scalar_7_slot_misc_rail", ["vector_round_shroud_mk1_11inch_modular"] = "kalis_scalar_mk11_handguard", ["vector_round_shroud_mk1_9inch_modular"] = "kalis_scalar_mk9_handguard", ["vector_std_mag_eject"] = "kalis_scalar_std_mag_release", ["vector_std_trigger"] = "kalis_scalar_gen1_trigger", ["virticon_acog_ta01_4x_scope"] = "virticon_arcs_ta01_4x_scope",
    ["virticon_acog_ta01_4x_scope_carry_handle"] = "virticon_arcs_ta01_4x_scope_carry_handle", ["virticon_acog_ta11d_bac"] = "virticon_arcs_ta11d_bac", ["virticon_acog_ta11d_bac_carry_handle"] = "virticon_arcs_ta11d_bac_carry_handle", ["virticon_acog_ta31_comspec_4x_scope"] = "virticon_arcs_ta31_comspec_4x_scope", ["virticon_acog_ta31_comspec_4x_scope_carry_handle"] = "virticon_arcs_ta31_comspec_4x_scope_carry_handle", ["virticon_acog_ta31_milspec_4x_scope"] = "virticon_arcs_ta31_milspec_4x_scope", ["virticon_acog_ta31_milspec_4x_scope_carry_handle"] = "virticon_arcs_ta31_milspec_4x_scope_carry_handle", ["virticon_compact_acog_3x24_ta50c_green"] = "virticon_compact_arcs_3x24_ta50c_green", ["virticon_compact_acog_3x24_ta50c_red"] = "virticon_compact_arcs_3x24_ta50c_red", ["virticon_compact_acog_ac12041_mount"] = "virticon_compact_arcs_ac12041_mount", ["virticon_rm33_mount"] = "virticon_dr33_mount",
    ["virticon_rm34_ac12036_mount"] = "virticon_dr34_ac12036_mount", ["virticon_rm34_rmr_adapter"] = "virticon_dr34_rmr_adapter", ["virticon_rm35_acog_mount"] = "virticon_rm35_arcs_mount", ["virticon_rmr_rm01_type2_auto_led_reflex"] = "virticon_drd_dr01_type2_auto_led_reflex", ["virticon_rmr_rm05_dual_illuminated_reflex"] = "virticon_drd_dr05_dual_illuminated_reflex", ["virticon_rmr_rm06_type2_adj_led_reflex"] = "virticon_drd_dr06_type2_adj_led_reflex", ["virticon_sro_reflex_sight"] = "virticon_cro_reflex_sight", ["virticon_srs02"] = "virticon_sps02", ["whitehouse_compm_30mm_mount"] = "whitehouse_duty_30mm_mount", ["whitner_defense_true_zero_acro_mount"] = "whitner_defense_true_zero_ecro_mount", ["zvetech_pf940_slide_cover"] = "zvetech_kosch_slide_cover",
}
-- END ATTACHMENT_ALIASES

-- Everything except the optional display names is embedded, so the script also
-- works when pasted into the console with no network access.
local AttachmentData = {
    ALIASES = ATTACHMENT_ALIASES,
    resolve = function(att_id)
        if not att_id then return nil end
        local seen = {}
        local current = att_id
        while ATTACHMENT_ALIASES[current] and not seen[current] do
            seen[current] = true
            current = ATTACHMENT_ALIASES[current]
        end
        return current
    end,
}

-- id -> in-game name; nil if LOAD_NAMES is off or the module could not be loaded.
local display_names, names_version = nil, nil
if LOAD_NAMES then
    local ok, mod = pcall(function() return require(NAMES_URL) end)
    if ok and type(mod) == "table" and type(mod.NAMES) == "table" then
        display_names, names_version = mod.NAMES, mod.VERSION
    end
end

local DISPLAY_ACRONYMS = {
    acog = "ACOG", afg = "AFG", ak = "AK", ar = "AR", bcm = "BCM",
    cqb = "CQB", dd = "DD", ecm = "ECM", eotech = "EOTech", fal = "FAL",
    fmj = "FMJ", g3 = "G3", hp = "HP", kag = "KAG", kac = "KAC",
    m4 = "M4", m4a1 = "M4A1", m16 = "M16", mlok = "M-LOK", moe = "MOE",
    moa = "MOA", mp5 = "MP5", mp5k = "MP5K", otm = "OTM", pdw = "PDW",
    pepr = "P.E.P.R.", pmag = "PMAG", prs = "PRS", qd = "QD", rmr = "RMR",
    sa58 = "SA58", scar = "SCAR", scarh = "SCAR-H", scarl = "SCAR-L",
    spr = "SPR", sro = "SRO", std = "Standard", urgi = "URG-I",
}

local function fallback_display_name(id)
    local words = {}
    for part in string.gmatch(tostring(id or "Unknown"), "[^_]+") do
        local lower = string.lower(part)
        local display = DISPLAY_ACRONYMS[lower]
        if not display then
            local first = string.match(lower, "^.") or ""
            display = string.upper(first) .. string.sub(lower, 2)
        end
        table.insert(words, display)
    end
    return table.concat(words, " ")
end

-- Works for attachment and weapon ids alike; balancing.csv names both.
local function display_name(id)
    return (display_names and display_names[id]) or fallback_display_name(id)
end

-- Printed width in characters (some names contain multi-byte UTF-8 letters).
local function text_width(s)
    return (utf8 and utf8.len(s)) or #s
end

local function print_attachment_stats(target_player)
    -- 1. Locate target human player
    local my_player = target_player
    if type(my_player) == "string" and players and type(players.get) == "function" then
        my_player = players.get(my_player)
    end
    if not my_player and players and type(players.get_all) == "function" then
        for _, plr in ipairs(players.get_all()) do
            local is_bot = false
            if type(plr.is_bot) == "function" then
                local ok, res = pcall(function() return plr.is_bot() end)
                if ok then is_bot = res end
            end
            if not is_bot then
                my_player = plr
                break
            end
        end
    end

    if my_player and type(my_player.get_profile_stats) == "function" then
        local stats = my_player.get_profile_stats() or {}

        -- 2. Aggregate kills per canonical attachment id
        local raw_weapons = stats.weapon or {}
        local totals = {}
        for w_id, w_data in pairs(raw_weapons) do
            local att_stats = (type(w_data) == "table" and w_data.attachment_stats) or {}
            for att_id, data in pairs(att_stats) do
                local kills = 0
                if type(data) == "table" then
                    local raw_kills = data.kills
                    if raw_kills == nil then raw_kills = data.kill_count end
                    kills = tonumber(raw_kills) or 0
                elseif type(data) == "number" then
                    kills = data
                end
                if kills > 0 then
                    local canon = AttachmentData.resolve(att_id)
                    local b = totals[canon]
                    if not b then
                        b = {}
                        b.kills = 0
                        b.weapons = {}
                        totals[canon] = b
                    end
                    b.kills = (tonumber(b.kills) or 0) + (tonumber(kills) or 0)
                    b.weapons[w_id] = (tonumber(b.weapons[w_id]) or 0) + (tonumber(kills) or 0)
                end
            end
        end
        local sorted = {}
        for att_id, info in pairs(totals) do
            local top_gun, top_kills = "N/A", 0
            for g_id, g_k in pairs(info.weapons) do
                if g_k > top_kills or (g_k == top_kills and g_id < top_gun) then
                    top_gun, top_kills = g_id, g_k
                end
            end
            table.insert(sorted, { id = att_id, kills = info.kills, top_gun = top_gun, top_gun_kills = top_kills })
        end
        table.sort(sorted, function(a, b) return a.kills > b.kills end)

        -- 3. Print, padding the name column to the longest name
        local names, width = {}, 0
        for i, it in ipairs(sorted) do
            names[i] = display_name(it.id)
            width = math.max(width, text_width(names[i]))
        end
        print(string.format("\n================ ALL %d ATTACHMENTS BY KILLS ================", #sorted))
        if names_version then
            print("-- names: deadline-balancing " .. tostring(names_version))
        else
            print("-- names: prettified ids (attachment_names module not loaded)")
        end
        for i, it in ipairs(sorted) do
            print(string.format("#%-3d %s | Kills: %-6d | Top Gun: %s (%d)",
                i,
                names[i] .. string.rep(" ", width - text_width(names[i])),
                it.kills,
                display_name(it.top_gun),
                it.top_gun_kills))
        end

        return sorted
    else
        print("Could not retrieve player profile stats.")
    end
end

-- Persist in shared environment for subsequent console executions
if shared then
    shared.print_attachment_stats = print_attachment_stats
end

-- Run immediately on execution
print_attachment_stats()

return print_attachment_stats
