// Board inside the enclosure, for previews and renders
view = "exploded";   // "assembled", "exploded", "no_lid"
include <enclosure.scad>
include <pcb3d.scad>

module board_in_place() {
    translate([wall_thickness - inner_x_min, wall_thickness - inner_y_min + circuit_width, board_top_z]) rotate([180, 0, 0]) pcb3d();
    color("#1f5f2a") translate([wall_thickness - inner_x_min - blank_margin_x, wall_thickness - inner_y_min - blank_margin_y, board_bottom_z + 0.01])
        cube([blank_length, blank_width, board_thickness - 0.02]);
}

module lid_mounted_parts() {
    lid_inner_z = floor_thickness + inner_height;
    color("#9a9a9a") translate([to_box(speaker_pos[0], speaker_pos[1])[0], to_box(speaker_pos[0], speaker_pos[1])[1], lid_inner_z - speaker_height]) cylinder(d = speaker_d, h = speaker_height);
    color("#c0c0c0") translate([to_box(pot_pos[0], pot_pos[1])[0], to_box(pot_pos[0], pot_pos[1])[1], lid_inner_z - 9]) cylinder(d = pot_body_d, h = 9);
    color("#555") translate([to_box(mic_pos[0], mic_pos[1])[0], to_box(mic_pos[0], mic_pos[1])[1], lid_inner_z - 6.7]) cylinder(d = mic_capsule_d, h = 6.7);
    color("#d33") translate([to_box(button_pos[0], button_pos[1])[0], to_box(button_pos[0], button_pos[1])[1], board_top_z + 5]) button();
    color("#222") translate([to_box(pot_pos[0], pot_pos[1])[0], to_box(pot_pos[0], pot_pos[1])[1], lid_inner_z + lid_thickness + 1.5]) mirror([0, 0, 1]) translate([0, 0, -15]) import("stl/knob.stl");
    color("#111") translate([outer_length + 4, to_box(0, antenna_y)[1], antenna_z]) rotate([0, 90, 0]) cylinder(d = 9, h = 12);
    color("#111") translate([outer_length + 14, to_box(0, antenna_y)[1], antenna_z]) rotate([0, 90, 0]) cylinder(d = 10, h = 90);
    color("#eee") translate([-30, to_box(0, usb_y)[1] - 5, usb_z - 4]) cube([28, 10, 8]);
}

lift = view == "exploded" ? 45 : 0;
color("#e8e8e8") base();
board_in_place();
translate([0, 0, lift]) lid_mounted_parts();
if (view == "assembled") color("#e8e8e8") lid_assembled();
if (view == "exploded") color("#e8e8e8") lid_assembled(lift);
