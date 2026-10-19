// RF intercom enclosure (OpenSCAD)
// Board: 85 x 52 mm circuit (hardware/intercom.kicad_pcb) on a 90 x 60 mm hand-cut copper-clad blank.
// The board sits upside down: B side (button, nRF24, PAM8403) faces the lid, F side (Nano, C7) faces the floor.
// Board coordinates are already mirrored: seen from above, looking at the lid.
// Nano USB on the left wall, nRF24 SMA antenna on the right wall.
// Print rules: PETG, no overhangs, M3 self-tapping hole = 2.8, M3 clearance hole = 3.8,
// no captive nuts, horizontal holes are teardrops, printed holes come out ~0.3 smaller (HOLE_COMPENSATION).
//
// Export with:  openscad -D 'part="base"' -o stl/base.stl enclosure.scad   (part = base | lid | button)

part = "none";   // "base", "lid", "button", "none"

$fn = 64;
HOLE_COMPENSATION = 0.3;
board_clearance   = 0.5;
lid_lip_clearance = 0.6;        // gap between the lid lip and the inner walls

// ---------- board ----------
circuit_length = 85.0; circuit_width = 52.0; board_thickness = 1.6;   // KiCad coordinates
blank_length = 90; blank_width = 60;                                   // physical copper-clad blank
blank_margin_x = (blank_length - circuit_length) / 2;
blank_margin_y = (blank_width - circuit_width) / 2;
nano_overhang     = 3.56;       // Nano + USB stick out past the left edge
radio_module_y_min = -0.7;      // the nRF24 module sticks out slightly past the bottom edge

// ---------- box ----------
wall_thickness = 2.0; floor_thickness = 2.0; lid_thickness = 2.0;
space_below_board = 19.0;       // floor to the F side: C7 (1000 uF) measured 18 mm
space_above_board = 27.5;       // B side to the lid: SMA measured 21.8 mm + speaker 5 mm
inner_x_min = min(-blank_margin_x, -nano_overhang) - board_clearance;
inner_x_max = circuit_length + blank_margin_x + board_clearance;
inner_y_min = min(-blank_margin_y, radio_module_y_min - 0.3) - board_clearance;
inner_y_max = circuit_width + blank_margin_y + board_clearance;
inner_length = inner_x_max - inner_x_min;
inner_width  = inner_y_max - inner_y_min;
board_bottom_z = floor_thickness + space_below_board;   // F side
board_top_z    = board_bottom_z + board_thickness;      // B side
inner_height   = space_below_board + board_thickness + space_above_board;
outer_length = inner_length + 2 * wall_thickness;
outer_width  = inner_width + 2 * wall_thickness;
outer_height = floor_thickness + inner_height;

// board coordinates (KiCad, mirrored) -> box coordinates
function to_box(x, y) = [wall_thickness - inner_x_min + x, wall_thickness - inner_y_min + y];

// ---------- support columns under the blank corners ----------
support_corners = [
    [-blank_margin_x, -blank_margin_y],
    [circuit_length + blank_margin_x - 5, -blank_margin_y],
    [-blank_margin_x, circuit_width + blank_margin_y - 5],
    [circuit_length + blank_margin_x - 5, circuit_width + blank_margin_y - 5]
];

// ---------- lid screws: horizontal, through the long walls ----------
SELF_TAP_HOLE = 2.8; CLEARANCE_HOLE = 3.8;
front_screw_x = [22, 80];
back_screw_x  = [20, 78];
screw_boss_height = 6; screw_boss_depth = 4; screw_boss_length = 8;
screw_depth_below_rim = 3.5;    // screw axis below the top of the wall

// ---------- openings ----------
usb_y = 26.62;                          // Nano USB center, board Y
usb_z = board_bottom_z - 14.22;         // measured: USB top 15.77 mm, connector 3.1 mm
usb_width = 12; usb_height = 8;
antenna_y = 6.94;                       // SMA center, board Y
antenna_z = board_top_z + 18.8;         // measured: SMA top 21.8 mm, thread 6 mm
antenna_thread_d = 6.0;
antenna_base_d   = 10.5;                // antenna base measured 9.9 mm, plus clearance

// ---------- lid parts ----------
speaker_d = 40; speaker_height = 5; speaker_pos = [63, 30];
pot_thread_d = 7; pot_body_d = 16.4; pot_pos = [9, 11];
button_pos = [35.75, 25.75];            // SW1 center
button_d   = 8;
mic_capsule_d = 9.7; mic_pos = [20, 38];

// horizontal hole along Y, teardrop with a flat top (+Z) so it prints without support
module teardrop_hole(d, length) {
    rotate([90, 0, 0]) linear_extrude(length, center = true)
        intersection() {
            hull() { circle(d = d); translate([0, d/2 / sin(45)]) square(0.01, center = true); }
            translate([-d, -d]) square([2*d, d + d/2 + 0.4]);
        }
}

// ================= BASE =================
module base() {
    difference() {
        union() {
            difference() {
                cube([outer_length, outer_width, outer_height]);
                translate([wall_thickness, wall_thickness, floor_thickness]) cube([inner_length, inner_width, inner_height + 1]);
            }
            for (corner = support_corners) support_column(corner);
        }
        for (x = front_screw_x) translate([to_box(x, 0)[0], wall_thickness/2, outer_height - screw_depth_below_rim])
            teardrop_hole(CLEARANCE_HOLE + HOLE_COMPENSATION, wall_thickness + 2);
        for (x = back_screw_x)  translate([to_box(x, 0)[0], outer_width - wall_thickness/2, outer_height - screw_depth_below_rim])
            teardrop_hole(CLEARANCE_HOLE + HOLE_COMPENSATION, wall_thickness + 2);
        // USB on the left wall: rectangular opening
        translate([-1, to_box(0, usb_y)[1] - (usb_width + HOLE_COMPENSATION)/2, usb_z - (usb_height + HOLE_COMPENSATION)/2])
            cube([wall_thickness + 2, usb_width + HOLE_COMPENSATION, usb_height + HOLE_COMPENSATION]);
        // SMA on the right wall: hole for the antenna base + slot up to the rim so the board can drop in
        translate([outer_length - wall_thickness/2, to_box(0, antenna_y)[1], antenna_z]) rotate([0, 90, 0])
            cylinder(d = antenna_base_d + HOLE_COMPENSATION, h = wall_thickness + 2, center = true);
        translate([outer_length - wall_thickness - 1, to_box(0, antenna_y)[1] - (antenna_thread_d + HOLE_COMPENSATION + 0.4)/2, antenna_z])
            cube([wall_thickness + 2, antenna_thread_d + HOLE_COMPENSATION + 0.4, outer_height]);
    }
}

// 5 x 5 column from the floor up to the F side, merged into the wall when close to it
module support_column(corner) {
    x0 = corner[0] < 0 ? inner_x_min : corner[0];
    x1 = corner[0] > circuit_length - 6 ? inner_x_max : corner[0] + 5;
    y0 = corner[1] < 0 ? inner_y_min : corner[1];
    y1 = corner[1] > circuit_width - 6 ? inner_y_max : corner[1] + 5;
    translate([wall_thickness - inner_x_min + x0, wall_thickness - inner_y_min + y0, floor_thickness])
        cube([x1 - x0, y1 - y0, space_below_board]);
}

// ================= LID =================
// Modeled in the assembled orientation (box coordinates), outer face at z = 0.
module lid() {
    antenna_tab_height = inner_height - (antenna_z - floor_thickness) - (antenna_base_d + HOLE_COMPENSATION)/2 - 0.3;
    difference() {
        union() {
            lid_plate();
            // lip that fits inside the walls
            difference() {
                translate([wall_thickness + lid_lip_clearance, wall_thickness + lid_lip_clearance, lid_thickness])
                    cube([inner_length - 2*lid_lip_clearance, inner_width - 2*lid_lip_clearance, 3]);
                translate([wall_thickness + lid_lip_clearance + 1.2, wall_thickness + lid_lip_clearance + 1.2, lid_thickness - 1])
                    cube([inner_length - 2*lid_lip_clearance - 2.4, inner_width - 2*lid_lip_clearance - 2.4, 5]);
            }
            // screw bosses
            for (x = front_screw_x) translate([to_box(x, 0)[0] - screw_boss_length/2, wall_thickness + lid_lip_clearance, lid_thickness])
                cube([screw_boss_length, screw_boss_depth, screw_boss_height]);
            for (x = back_screw_x)  translate([to_box(x, 0)[0] - screw_boss_length/2, outer_width - wall_thickness - lid_lip_clearance - screw_boss_depth, lid_thickness])
                cube([screw_boss_length, screw_boss_depth, screw_boss_height]);
            // tab that closes the antenna slot
            translate([outer_length - wall_thickness - 0.01, to_box(0, antenna_y)[1] - (antenna_thread_d + HOLE_COMPENSATION)/2, lid_thickness])
                cube([wall_thickness + 0.01, antenna_thread_d + HOLE_COMPENSATION, antenna_tab_height]);
            translate([to_box(speaker_pos[0], speaker_pos[1])[0], to_box(speaker_pos[0], speaker_pos[1])[1], lid_thickness]) speaker_ring();
            // button guide
            translate([to_box(button_pos[0], button_pos[1])[0], to_box(button_pos[0], button_pos[1])[1], lid_thickness])
                difference() { cylinder(d = button_d + HOLE_COMPENSATION + 2.4, h = 2); translate([0, 0, -1]) cylinder(d = button_d + HOLE_COMPENSATION + 0.4, h = 4); }
            // microphone capsule holder
            translate([to_box(mic_pos[0], mic_pos[1])[0], to_box(mic_pos[0], mic_pos[1])[1], lid_thickness])
                difference() { cylinder(d = mic_capsule_d + HOLE_COMPENSATION + 2.4, h = 4); translate([0, 0, -1]) cylinder(d = mic_capsule_d + HOLE_COMPENSATION, h = 6); }
        }
        for (x = front_screw_x) translate([to_box(x, 0)[0], wall_thickness + lid_lip_clearance + screw_boss_depth/2, lid_thickness + screw_depth_below_rim])
            teardrop_hole(SELF_TAP_HOLE + HOLE_COMPENSATION, screw_boss_depth + 6);
        for (x = back_screw_x)  translate([to_box(x, 0)[0], outer_width - wall_thickness - lid_lip_clearance - screw_boss_depth/2, lid_thickness + screw_depth_below_rim])
            teardrop_hole(SELF_TAP_HOLE + HOLE_COMPENSATION, screw_boss_depth + 6);
        translate([to_box(speaker_pos[0], speaker_pos[1])[0], to_box(speaker_pos[0], speaker_pos[1])[1], -1]) speaker_slots(speaker_d - 8, 2.0, 4.0);
        translate([to_box(pot_pos[0], pot_pos[1])[0], to_box(pot_pos[0], pot_pos[1])[1], -1]) cylinder(d = pot_thread_d + HOLE_COMPENSATION + 0.2, h = 10);
        translate([to_box(button_pos[0], button_pos[1])[0], to_box(button_pos[0], button_pos[1])[1], -1]) cylinder(d = button_d + HOLE_COMPENSATION + 0.4, h = 10);
        // three-arm star over the mic: a single continuous opening, so the first layer
        // is one big loop that sticks to the bed instead of tiny rings that get dragged
        translate([to_box(mic_pos[0], mic_pos[1])[0], to_box(mic_pos[0], mic_pos[1])[1], -1])
            for (a = [90, 210, 330]) rotate(a) hull() { cylinder(d = 1.6, h = 10, $fn = 20); translate([2.4, 0, 0]) cylinder(d = 1.6, h = 10, $fn = 20); }
    }
}

// Lid plate: 0.3 mm smaller than the base on each side, with a chamfer on the bed edge
// to compensate the first-layer squish (elephant foot)
LID_INSET = 0.3; LID_CHAMFER = 0.5;
module lid_plate() {
    hull() {
        translate([LID_INSET + LID_CHAMFER, LID_INSET + LID_CHAMFER, 0])
            cube([outer_length - 2*LID_INSET - 2*LID_CHAMFER, outer_width - 2*LID_INSET - 2*LID_CHAMFER, 0.01]);
        translate([LID_INSET, LID_INSET, LID_CHAMFER])
            cube([outer_length - 2*LID_INSET, outer_width - 2*LID_INSET, lid_thickness - LID_CHAMFER]);
    }
}

// ring that centers the speaker + 3 snap clips that lock its rim
clip_angles = [0, 120, 200];    // no clip over the nRF24 module
clip_width = 6; clip_hook = 0.8;
module speaker_ring() {
    inner_r = (speaker_d + HOLE_COMPENSATION) / 2;
    outer_r = inner_r + 1.2;
    clip_height = speaker_height + 0.2;
    difference() {
        union() {
            cylinder(r = outer_r, h = speaker_height);
            for (a = clip_angles) rotate(a) intersection() {
                difference() { cylinder(r = outer_r, h = clip_height + 1.4); translate([0, 0, -1]) cylinder(r = inner_r, h = clip_height + 3); }
                translate([0, -clip_width/2, 0]) cube([outer_r + 1, clip_width, clip_height + 2]);
            }
            for (a = clip_angles) rotate(a) translate([inner_r, 0, clip_height])
                rotate([90, 0, 0]) linear_extrude(clip_width, center = true)
                    polygon([[0.01, 0], [-clip_hook, 0], [-clip_hook, 0.4], [0.01, 0.4 + clip_hook]]);
        }
        translate([0, 0, -1]) cylinder(r = inner_r, h = speaker_height + 1);
        // cuts on both sides of each clip so it can flex
        for (a = clip_angles, side = [-1, 1]) rotate(a) translate([inner_r - 1, side * (clip_width/2 + 0.5) - 0.5, 1.5]) cube([3, 1, clip_height + 3]);
    }
}

// speaker grille: parallel slots with rounded ends (long straight perimeters stick to the bed;
// small round holes used to come loose on the first layer)
module speaker_slots(area_d, slot_width, pitch) {
    r = area_d / 2;
    n = floor((r - slot_width/2) / pitch);
    for (j = [-n:n]) {
        y = j * pitch;
        half_length = sqrt(r*r - y*y) - slot_width/2;
        if (half_length > slot_width) hull() for (x = [-half_length, half_length]) translate([x, y, 0]) cylinder(d = slot_width, h = 10, $fn = 24);
    }
}

// ================= BUTTON =================
SW1_HEIGHT = 5.3;   // measured
button_travel = (outer_height + lid_thickness) - (board_top_z + SW1_HEIGHT);
module button() {
    cylinder(d = button_d + 3, h = 1.5);
    cylinder(d = button_d, h = button_travel + 1.5);
}

// The lid prints outer face down. To assemble it is flipped over its long edge, which swaps
// front and back. So the print file is mirrored in Y: once flipped, everything lands where
// it was modeled. (Without this the screw holes ended up 2 mm off and the antenna tab
// on the wrong side.)
module lid_for_printing() { translate([0, outer_width, 0]) mirror([0, 1, 0]) lid(); }

module lid_assembled(lift = 0) { translate([0, 0, outer_height + lid_thickness + lift]) mirror([0, 0, 1]) lid(); }

if (part == "base") base();
else if (part == "lid") lid_for_printing();
else if (part == "button") button();
