import { Controller } from "@hotwired/stimulus"

// Renders one admin usage-analytics chart with chartkick + Chart.js, both
// dynamically imported so Chart.js loads only on the dashboard — never preloaded
// onto ordinary discovery pages (the tify/ace-builds posture). Data + colors are
// passed as Stimulus values; the element is the chart target.
export default class extends Controller {
  static values = {
    kind: { type: String, default: "line" },
    dataset: { type: Array, default: [] },
    colors: { type: Array, default: [] },
    scale: { type: String, default: "linear" },
  }

  async connect() {
    // Both are UMD bundles that assign globals (window.Chart / window.Chartkick)
    // rather than ESM exports — load Chart.js first so chartkick adopts it.
    await import("Chart.bundle")
    await import("chartkick")
    const Chartkick = window.Chartkick
    if (!Chartkick) return
    if (Chartkick.use && window.Chart) Chartkick.use(window.Chart)

    const chartClasses = { column: Chartkick.ColumnChart, pie: Chartkick.PieChart, line: Chartkick.LineChart }
    const ChartClass = chartClasses[this.kindValue] || Chartkick.LineChart
    const log = this.scaleValue === "log"

    // A pie chart's "series" is one flat label/value list, not per-series lines —
    // its legend should always show (the slice labels), and points/curve are
    // line-chart-only options that don't apply.
    const options = this.kindValue === "pie"
      ? { colors: this.colorsValue, library: { maintainAspectRatio: false, plugins: { legend: { display: true, position: "right" } } } }
      : {
          colors: this.colorsValue,
          points: false,
          curve: false,
          library: {
            maintainAspectRatio: false,
            plugins: { legend: { display: this.datasetValue.length > 1, position: "bottom" } },
            ...(log && { scales: { y: this.logAxis() } }),
          },
        }

    const dataset = log ? this.withoutZeros(this.datasetValue) : this.datasetValue
    this.chart = new ChartClass(this.element, dataset, options)
  }

  disconnect() {
    this.chart?.destroy?.()
  }

  // The floor sits below 1 so a day with a single event still draws a bar.
  // Labels only 1, 2 and 5 in each decade; the rest would crowd the axis.
  logAxis() {
    return {
      type: "logarithmic",
      min: 0.6,
      grid: { display: false },
      ticks: {
        autoSkip: false,
        callback: (value) => {
          const leading = value / 10 ** Math.floor(Math.log10(value))
          return [1, 2, 5].some((n) => Math.abs(leading - n) < 1e-6) ? value.toLocaleString() : ""
        },
      },
    }
  }

  // A log axis has no 0, so a quiet day becomes a gap instead of a bar.
  withoutZeros(dataset) {
    return dataset.map((series) => ({
      ...series,
      data: Object.fromEntries(Object.entries(series.data).map(([day, n]) => [day, n > 0 ? n : null])),
    }))
  }
}
