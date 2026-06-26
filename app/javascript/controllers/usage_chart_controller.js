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
    await import("Chart.bundle") // registers window.Chart
    const { default: Chartkick } = await import("chartkick")
    if (window.Chart) Chartkick.use(window.Chart)

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
