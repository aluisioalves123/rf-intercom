// Volume knob for the potentiometer (6 mm knurled split shaft)
// Print with the top face on the bed and the shaft hole facing up.
$fn = 96;
knob_d          = 16;     // outer diameter
knob_height     = 15;     // total height
shaft_hole_d    = 6.0;    // prints ~5.7 and grips the knurled shaft
shaft_hole_depth = 12;
nut_recess_d    = 11.5;   // recess on the underside that covers the pot nut
nut_recess_height = 2;
grip_grooves    = 18;     // grip grooves around the side

difference() {
    cylinder(d = knob_d, h = knob_height);
    // grip grooves
    for (i = [0 : grip_grooves - 1]) rotate(i * 360 / grip_grooves)
        translate([knob_d/2 + 0.3, 0, 1.5]) cylinder(d = 2, h = knob_height, $fn = 16);
    // chamfer on the top edge (the one on the bed)
    translate([0, 0, -0.01]) difference() {
        cylinder(d = knob_d + 2, h = 1);
        cylinder(d1 = knob_d - 2, d2 = knob_d, h = 1);
    }
    // position marker on the top face
    translate([knob_d/2 - 6.5, -0.6, -0.01]) cube([5.5, 1.2, 0.8]);
    // nut recess and shaft hole (underside of the knob, facing up here)
    translate([0, 0, knob_height - nut_recess_height]) cylinder(d = nut_recess_d, h = nut_recess_height + 1);
    translate([0, 0, knob_height - nut_recess_height - shaft_hole_depth]) cylinder(d = shaft_hole_d, h = shaft_hole_depth + 1);
}
