import QtQuick
import QtTest
import "../lib/btaudio.js" as A

// Run:  /usr/lib/qt6/bin/qmltestrunner -input ~/.config/quickshell/island/tests
TestCase {
    name: "BtAudio"

    function card(addr, active, profiles) {
        return { name: "bluez_card." + addr.replace(/:/g, "_"), active_profile: active,
                 properties: { "api.bluez5.address": addr }, profiles: profiles }
    }
    function p(desc, prio, avail) {
        return { description: desc, sinks: 1, sources: 0, priority: prio,
                 available: avail === undefined ? true : avail }
    }
    // pactl -f json list cards, a Galaxy Buds2 (+ a non-bluez card)
    readonly property var buds: card("58:A6:39:D5:7F:EF", "a2dp-sink-sbc", {
        "off": p("Off", 0),
        "a2dp-sink-sbc": p("High Fidelity Playback (A2DP Sink, codec SBC)", 131),
        "a2dp-sink-sbc_xq": p("High Fidelity Playback (A2DP Sink, codec SBC-XQ)", 130),
        "a2dp-sink": p("High Fidelity Playback (A2DP Sink, codec AAC)", 132),
        "headset-head-unit": p("Headset Head Unit (HSP/HFP, codec CVSD)", 5)
    })
    readonly property var alsa: ({ name: "alsa_card.pci", active_profile: "x",
                                   properties: {}, profiles: { "x": p("Stereo", 1) } })

    function test_parse_bad_json() { compare(Object.keys(A.parse("nope")).length, 0) }
    function test_parse_skips_non_bluez() {
        const m = A.parse(JSON.stringify([alsa, buds]))
        compare(Object.keys(m).join(), "58:A6:39:D5:7F:EF")
    }
    function test_parse_card_and_active() {
        const c = A.parse(JSON.stringify([buds]))["58:A6:39:D5:7F:EF"]
        compare(c.card, "bluez_card.58_A6_39_D5_7F_EF")
        compare(c.active, "a2dp-sink-sbc")
    }
    function test_options_hifi_by_priority_then_headset_no_off() {
        const o = A.parse(JSON.stringify([buds]))["58:A6:39:D5:7F:EF"].options
        compare(o.map(x => x.name).join(),
                "a2dp-sink,a2dp-sink-sbc,a2dp-sink-sbc_xq,headset-head-unit")
        compare(o.map(x => x.label).join(), "AAC,SBC,SBC-XQ,Headset")
        compare(o[0].call, false)
        compare(o[3].call, true)
    }
    function test_options_skip_unavailable() {
        const c = card("AA:BB:CC:DD:EE:FF", "a2dp-sink", {
            "a2dp-sink": p("High Fidelity Playback (A2DP Sink, codec AAC)", 132),
            "a2dp-sink-aptx": p("High Fidelity Playback (A2DP Sink, codec aptX)", 140, false)
        })
        compare(A.parse(JSON.stringify([c]))["AA:BB:CC:DD:EE:FF"].options.length, 1)
    }
    function test_several_headset_codecs_get_named() {
        const c = card("AA:BB:CC:DD:EE:FF", "headset-head-unit", {
            "headset-head-unit": p("Headset Head Unit (HSP/HFP, codec mSBC)", 30),
            "headset-head-unit-cvsd": p("Headset Head Unit (HSP/HFP, codec CVSD)", 20)
        })
        compare(A.parse(JSON.stringify([c]))["AA:BB:CC:DD:EE:FF"].options.map(x => x.label).join(),
                "Headset mSBC,Headset CVSD")
    }
    function test_label_without_codec_falls_back() {
        const c = card("AA:BB:CC:DD:EE:FF", "a2dp-sink", {
            "a2dp-sink": p("High Fidelity Playback (A2DP Sink)", 10)
        })
        compare(A.parse(JSON.stringify([c]))["AA:BB:CC:DD:EE:FF"].options[0].label, "Hi-Fi")
    }
    function test_active_label() {
        const c = A.parse(JSON.stringify([buds]))["58:A6:39:D5:7F:EF"]
        compare(A.activeLabel(c), "SBC")
        compare(A.activeLabel(undefined), "")
    }
}
