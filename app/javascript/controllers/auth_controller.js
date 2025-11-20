import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="auth"
export default class extends Controller {
  static values = {
    sessionToken: String
  }

  connect() {
    console.log("🔌 Auth controller connected")
    console.log("📍 Session token:", this.sessionTokenValue)

    if (!this.sessionTokenValue) {
      console.error("❌ No session token provided")
      return
    }

    this.setupCable()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      console.log("🔌 Auth controller disconnected")
    }
  }

  setupCable() {
    const consumer = createConsumer()

    this.subscription = consumer.subscriptions.create(
      {
        channel: "AuthChannel",
        session_token: this.sessionTokenValue
      },
      {
        connected: () => {
          console.log("✅ Connected to AuthChannel")
        },

        disconnected: () => {
          console.log("❌ Disconnected from AuthChannel")
        },

        received: (data) => {
          console.log("📨 Received data:", data)

          if (data.authenticated) {
            console.log("🎉 Authentication successful!")

            // Show success message
            this.showSuccessMessage()

            // Redirect after a short delay
            setTimeout(() => {
              window.location.href = data.redirect_url || "/dashboard"
            }, 1000)
          }
        }
      }
    )
  }

  showSuccessMessage() {
    // Create and show a success notification
    const notification = document.createElement("div")
    notification.className = "fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fade-in"
    notification.innerHTML = `
      <div class="flex items-center">
        <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        <span class="font-medium">Авторизация успешна! Перенаправляем...</span>
      </div>
    `

    document.body.appendChild(notification)

    // Remove after animation
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}
