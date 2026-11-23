import QtQuick

// Sparkline: a line over a soft accent fill. `values` oldest → newest;
// `max` 0 = scale to the data. Two series: `values` (accent) and `values2`
// (lighter, dashed), sharing the scale.
Canvas {
    id: g
    property var values: []
    property var values2: []
    property real max: 0
    property int slots: 60
    property color tone: Look.accent2
    property color tone2: Look.alpha(Look.fg, 0.55)

    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onToneChanged: requestPaint()
    onWidthChanged: requestPaint()

    function series(ctx, vals, top, color, fill, dashed) {
        if (vals.length < 2) return
        const step = width / (slots - 1), x0 = width - (vals.length - 1) * step
        const y = v => height - 2 - (height - 4) * Math.min(1, v / top)
        ctx.beginPath()
        ctx.moveTo(x0, y(vals[0]))
        for (let i = 1; i < vals.length; i++) ctx.lineTo(x0 + i * step, y(vals[i]))
        ctx.lineWidth = 1.6
        ctx.strokeStyle = color
        ctx.setLineDash(dashed ? [3, 3] : [])
        ctx.stroke()
        if (fill) {
            ctx.lineTo(width, height); ctx.lineTo(x0, height); ctx.closePath()
            const gr = ctx.createLinearGradient(0, 0, 0, height)
            gr.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.35))
            gr.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0))
            ctx.fillStyle = gr
            ctx.fill()
        }
    }
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const top = max > 0 ? max : Math.max(1e-9, ...values, ...values2)
        series(ctx, values2, top, tone2, false, true)
        series(ctx, values, top, tone, true, false)
    }
}
