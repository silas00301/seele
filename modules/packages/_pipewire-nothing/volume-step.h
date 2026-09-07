/* Nothing Headphone (1) uses seven AVRCP units per roller detent.
 * Convert remote detents to five percentage points on the 0..127 scale.
 * Host-requested values are already recorded before their acknowledgements,
 * so an unchanged value must remain untouched to avoid a feedback loop. */
static int nothing_volume_step(int previous, int incoming)
{
    if (previous < 0 || previous > 127 || incoming < 0 || incoming > 127)
        return incoming;
    int delta = incoming - previous;
    if (delta == 0 || delta % 7 != 0)
        return incoming;
    int percent = (previous * 100 + 63) / 127 + (delta / 7) * 5;
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    return (percent * 127 + 50) / 100;
}
