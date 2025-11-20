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
    console.log('📊 loadAnalyticsData called')
    try {
      const response = await fetch(`/restaurants/${this.restaurantIdValue}/analytics_data?period=${this.periodValue}`)
      console.log('📡 Response received:', response.status)

      if (!response.ok) {
        throw new Error('Failed to fetch analytics data')
      }

      const data = await response.json()
      console.log('📦 Data parsed:', data)

      if (data.success) {
        console.log('✅ Data success, updating UI...')
        this.updateMetrics(data.metrics)
        console.log('📈 Calling updateTimeline with', data.timeline.length, 'points')
        this.updateTimeline(data.timeline)
        this.updateAnomaliesTable(data.recent_anomalies)
        this.hideLoading()
      } else {
        this.showError(data.errors?.join(', ') || 'Unknown error')
      }
    } catch (error) {
      console.error('❌ Error loading analytics:', error)
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
      const rating = parseFloat(metrics.avg_rating) || 0
      this.ratingValueTarget.textContent = rating > 0 ? rating.toFixed(1) : 'N/A'
    }
  }

  updateTimeline(timelineData) {
    console.log('🎨 updateTimeline called')
    console.log('Has chartTarget?', this.hasChartTarget)
    console.log('Timeline data length:', timelineData?.length)

    if (!this.hasChartTarget || !timelineData || timelineData.length === 0) {
      console.log('⚠️ Early return - missing target or data')
      return
    }

    console.log('🎨 Getting canvas context...')
    const ctx = this.chartTarget.getContext('2d')
    console.log('Canvas context:', ctx)

    // Destroy existing chart if it exists
    if (this.chart) {
      this.chart.destroy()
    }

    // Prepare data for Chart.js - show actual status (1=open, 0=closed, null=error/unknown)
    const labels = timelineData.map(d => d.label)
    const actualStatusData = timelineData.map(d => {
      if (d.actual_status === 'open') return 1
      if (d.actual_status === 'closed') return 0
      return null  // error/unknown - will show as gap in chart
    })
    const expectedStatusData = timelineData.map(d => d.expected_status === 'open' ? 1 : 0)

    // Create anomaly points (yellow markers)
    const anomalyPoints = timelineData
      .map((d, i) => d.is_anomaly ? { x: i, y: actualStatusData[i] } : null)
      .filter(p => p !== null)

    console.log('📊 Creating chart with data:', {
      labels: labels.length,
      actualStatus: actualStatusData.length,
      expectedStatus: expectedStatusData.length,
      anomalies: anomalyPoints.length
    })

    try {
      this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Actual Status',
            data: actualStatusData,
            stepped: 'after',
            borderColor: '#16A34A',
            backgroundColor: (context) => {
              const value = context.parsed?.y
              return value === 1 ? 'rgba(22, 163, 74, 0.3)' : 'rgba(220, 38, 38, 0.3)'
            },
            borderWidth: 2,
            fill: 'origin',
            pointRadius: 0
          },
          {
            label: 'Expected (Schedule)',
            data: expectedStatusData,
            stepped: 'after',
            borderColor: '#9CA3AF',
            borderDash: [5, 5],
            borderWidth: 2,
            fill: false,
            pointRadius: 0
          },
          {
            label: 'Anomalies',
            data: anomalyPoints,
            type: 'scatter',
            pointRadius: 8,
            pointBackgroundColor: '#EAB308',
            pointBorderColor: '#fff',
            pointBorderWidth: 2
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
                if (context.dataset.type === 'scatter') {
                  return `Anomaly at ${context.label}`
                }
                const status = context.parsed.y === 1 ? 'Open' : 'Closed'
                return `${context.dataset.label}: ${status}`
              }
            }
          }
        },
        scales: {
          y: {
            min: 0,
            max: 1,
            ticks: {
              stepSize: 1,
              callback: function(value) {
                return value === 1 ? 'Open' : 'Closed'
              }
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
      console.log('✅ Chart created successfully!')
    } catch (error) {
      console.error('❌ Failed to create chart:', error)
    }
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
