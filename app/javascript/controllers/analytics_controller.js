import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "uptimeValue",
    "revenueLossValue",
    "anomaliesValue",
    "ratingValue",
    "chart",
    "anomaliesTable",
    "errorMessage"
  ]

  static values = {
    restaurantId: Number,
    period: String
  }

  connect() {
    console.log("Analytics controller connected")
    this.chart = null
    this.loadAnalyticsData()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  changePeriod(event) {
    const newPeriod = event.currentTarget.dataset.period
    this.periodValue = newPeriod

    // Update active tab styling
    document.querySelectorAll('.period-btn').forEach(btn => {
      btn.classList.remove('bg-white', 'text-gray-900', 'shadow-sm')
      btn.classList.add('text-gray-500', 'hover:text-gray-700')
    })
    event.currentTarget.classList.remove('text-gray-500', 'hover:text-gray-700')
    event.currentTarget.classList.add('bg-white', 'text-gray-900', 'shadow-sm')

    // Reload data
    this.showLoading()
    this.loadAnalyticsData()
  }

  async loadAnalyticsData() {
    try {
      const response = await fetch(`/restaurants/${this.restaurantIdValue}/analytics_data?period=${this.periodValue}`)

      if (!response.ok) {
        throw new Error('Failed to fetch analytics data')
      }

      const data = await response.json()

      if (data.success) {
        this.updateMetrics(data.metrics)
        this.updateTimeline(data.timeline)
        this.updateAnomaliesTable(data.recent_anomalies)
        this.hideLoading()
      } else {
        this.showError(data.errors?.join(', ') || 'Unknown error')
      }
    } catch (error) {
      console.error('Error loading analytics:', error)
      this.showError(error.message)
    }
  }

  updateMetrics(metrics) {
    // Update uptime
    if (this.hasUptimeValueTarget) {
      this.uptimeValueTarget.textContent = `${metrics.uptime_percentage.toFixed(1)}%`
    }

    // Update revenue loss
    if (this.hasRevenueLossValueTarget) {
      this.revenueLossValueTarget.textContent = this.formatCurrency(metrics.revenue_loss)
    }

    // Update anomalies count
    if (this.hasAnomaliesValueTarget) {
      this.anomaliesValueTarget.textContent = metrics.anomalies_count
    }

    // Update rating
    if (this.hasRatingValueTarget) {
      this.ratingValueTarget.textContent = metrics.avg_rating.toFixed(1)
    }
  }

  updateTimeline(timelineData) {
    if (!this.hasChartTarget || !timelineData || timelineData.length === 0) {
      return
    }

    const ctx = this.chartTarget.getContext('2d')

    // Destroy existing chart if it exists
    if (this.chart) {
      this.chart.destroy()
    }

    // Prepare data for Chart.js
    const labels = timelineData.map(d => d.label)
    const onlineData = timelineData.map(d => d.online)
    const closedData = timelineData.map(d => d.closed)
    const anomalyData = timelineData.map(d => d.anomalies)

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Online',
            data: onlineData,
            borderColor: '#16A34A',
            backgroundColor: 'rgba(22, 163, 74, 0.1)',
            tension: 0.3,
            fill: true
          },
          {
            label: 'Closed',
            data: closedData,
            borderColor: '#DC2626',
            backgroundColor: 'rgba(220, 38, 38, 0.1)',
            tension: 0.3,
            fill: true
          },
          {
            label: 'Anomalies',
            data: anomalyData,
            borderColor: '#EAB308',
            backgroundColor: 'rgba(234, 179, 8, 0.1)',
            tension: 0.3,
            fill: true,
            borderDash: [5, 5]
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            position: 'top',
            labels: {
              usePointStyle: true,
              padding: 15
            }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            titleFont: {
              size: 14,
              weight: 'bold'
            },
            bodyFont: {
              size: 13
            },
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.parsed.y} checks`
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0
            },
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    })
  }

  updateAnomaliesTable(anomalies) {
    if (!this.hasAnomaliesTableTarget) {
      return
    }

    if (!anomalies || anomalies.length === 0) {
      this.anomaliesTableTarget.innerHTML = ''
      document.getElementById('no-anomalies')?.classList.remove('hidden')
      return
    }

    document.getElementById('no-anomalies')?.classList.add('hidden')

    this.anomaliesTableTarget.innerHTML = anomalies.map(anomaly => `
      <tr class="border-b last:border-b-0">
        <td class="py-3 text-gray-900">${anomaly.formatted_time}</td>
        <td class="py-3">
          <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium ${this.getStatusClass(anomaly.expected_status)}">
            ${this.capitalizeStatus(anomaly.expected_status)}
          </span>
        </td>
        <td class="py-3">
          <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium ${this.getStatusClass(anomaly.actual_status)}">
            ${this.capitalizeStatus(anomaly.actual_status)}
          </span>
        </td>
        <td class="py-3">
          <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium ${anomaly.severity_badge}">
            ${this.capitalizeStatus(anomaly.severity)}
          </span>
        </td>
      </tr>
    `).join('')

    // Re-initialize Lucide icons for the new content
    if (typeof lucide !== 'undefined') {
      lucide.createIcons()
    }
  }

  getStatusClass(status) {
    const classes = {
      'open': 'bg-green-100 text-green-700',
      'closed': 'bg-red-100 text-red-700',
      'unknown': 'bg-gray-100 text-gray-700'
    }
    return classes[status] || 'bg-gray-100 text-gray-700'
  }

  capitalizeStatus(status) {
    return status.charAt(0).toUpperCase() + status.slice(1)
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  showLoading() {
    document.getElementById('loading-state')?.classList.remove('hidden')
    document.getElementById('metrics-cards')?.classList.add('hidden')
    document.getElementById('timeline-chart-container')?.classList.add('hidden')
    document.getElementById('anomalies-table-container')?.classList.add('hidden')
    document.getElementById('error-state')?.classList.add('hidden')
  }

  hideLoading() {
    document.getElementById('loading-state')?.classList.add('hidden')
    document.getElementById('metrics-cards')?.classList.remove('hidden')
    document.getElementById('timeline-chart-container')?.classList.remove('hidden')
    document.getElementById('anomalies-table-container')?.classList.remove('hidden')

    // Re-initialize Lucide icons after showing content
    if (typeof lucide !== 'undefined') {
      lucide.createIcons()
    }
  }

  showError(message) {
    document.getElementById('loading-state')?.classList.add('hidden')
    document.getElementById('error-state')?.classList.remove('hidden')

    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
    }

    // Re-initialize Lucide icons
    if (typeof lucide !== 'undefined') {
      lucide.createIcons()
    }
  }
}
