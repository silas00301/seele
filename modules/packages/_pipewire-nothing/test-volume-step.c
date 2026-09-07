#include <assert.h>
#include "volume-step.h"

int main(void)
{
    assert(nothing_volume_step(64, 71) == 70); /* 50 -> 55 */
    assert(nothing_volume_step(70, 63) == 64); /* 55 -> 50 */
    assert(nothing_volume_step(64, 78) == 76); /* two detents */
    assert(nothing_volume_step(64, 50) == 51); /* two down */
    assert(nothing_volume_step(-1, 72) == 72); /* initial discovery */
    assert(nothing_volume_step(70, 70) == 70); /* host acknowledgement */
    assert(nothing_volume_step(64, 70) == 70); /* unrelated update */
    assert(nothing_volume_step(0, 0) == 0);
    assert(nothing_volume_step(127, 127) == 127);
    for (int percent = 0; percent <= 100; percent += 5) {
        int raw = (percent * 127 + 50) / 100;
        if (raw + 7 <= 127) {
            int result = nothing_volume_step(raw, raw + 7);
            assert((result * 100 + 63) / 127 == percent + 5);
            assert(nothing_volume_step(result, result) == result);
        }
        if (raw - 7 >= 0) {
            int result = nothing_volume_step(raw, raw - 7);
            assert((result * 100 + 63) / 127 == percent - 5);
        }
    }
}
