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
  }

  async connect() {
    // Both are UMD bundles that assign globals (window.Chart / window.Chartkick)
    // rather than ESM exports — load Chart.js first so chartkick adopts it.
    await import("Chart.bundle")
    await import("chartkick")
    const Chartkick = window.Chartkick
    if (!Chartkick) return
    if (Chartkick.use && window.Chart) Chartkick.use(window.Chart)

    const ChartClass = this.kindValue === "column" ? Chartkick.ColumnChart : Chartkick.LineChart
    this.chart = new ChartClass(this.element, this.datasetValue, {
      colors: this.colorsValue,
      points: false,
      curve: false,
      library: {
        maintainAspectRatio: false,
        plugins: { legend: { display: this.datasetValue.length > 1, position: "bottom" } },
      },
    })
  }

  disconnect() {
    this.chart?.destroy?.()
  }
}
