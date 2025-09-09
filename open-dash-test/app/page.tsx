import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { CheckCircle, XCircle, Clock, Bell, Shield, Smartphone, TrendingUp, AlertTriangle } from "lucide-react"
import Link from "next/link"

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-white">
      {/* Header */}
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
              <Bell className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-gray-900">DeliveryTracker</span>
          </div>
          <nav className="hidden md:flex items-center space-x-6">
            <Link href="#features" className="text-gray-600 hover:text-green-600 transition-colors">
              Features
            </Link>
            <Link href="#pricing" className="text-gray-600 hover:text-green-600 transition-colors">
              Pricing
            </Link>
            <Link href="#contact" className="text-gray-600 hover:text-green-600 transition-colors">
              Contact
            </Link>
          </nav>
          <div className="flex items-center space-x-3">
            <Link href="/dashboard">
              <Button variant="ghost" className="text-gray-600 hover:text-green-600">
                Sign In
              </Button>
            </Link>
            <Link href="/onboarding">
              <Button className="bg-green-600 hover:bg-green-700 text-white">Get Started</Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="py-20 px-4">
        <div className="container mx-auto text-center">
          <Badge className="mb-6 bg-green-100 text-green-800 border-green-200">Protect Your Revenue 24/7</Badge>
          <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6 text-balance">
            Never Miss a <span className="text-green-600">Closed Store</span> Again
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto text-pretty">
            Automatically monitor your GoFood and GrabFood outlets. Get instant alerts when your store unexpectedly
            closes, preventing revenue loss of $70-200+ per day.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
            <Link href="/onboarding">
              <Button size="lg" className="bg-green-600 hover:bg-green-700 text-white px-8 py-3">
                Start 14-Day Free Trial
              </Button>
            </Link>
            <Button
              size="lg"
              variant="outline"
              className="border-green-600 text-green-600 hover:bg-green-50 px-8 py-3 bg-transparent"
            >
              Watch Demo
            </Button>
          </div>

          {/* Status Demo Cards */}
          <div className="grid md:grid-cols-2 gap-6 max-w-2xl mx-auto">
            <Card className="border-green-200 bg-green-50">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">Warung Bali Asli</CardTitle>
                  <CheckCircle className="w-6 h-6 text-green-600" />
                </div>
                <CardDescription>Canggu, Bali</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Status</span>
                  <Badge className="bg-green-600 text-white">Open</Badge>
                </div>
                <div className="flex items-center justify-between mt-2">
                  <span className="text-sm text-gray-600">Last Check</span>
                  <span className="text-sm text-gray-900">2 min ago</span>
                </div>
              </CardContent>
            </Card>

            <Card className="border-red-200 bg-red-50">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">Café Sunset</CardTitle>
                  <XCircle className="w-6 h-6 text-red-600" />
                </div>
                <CardDescription>Seminyak, Bali</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Status</span>
                  <Badge variant="destructive">Closed</Badge>
                </div>
                <div className="flex items-center justify-between mt-2">
                  <span className="text-sm text-gray-600">Alert Sent</span>
                  <span className="text-sm text-gray-900">Just now</span>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Problem Section */}
      <section className="py-16 px-4 bg-white">
        <div className="container mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">The Hidden Revenue Killer</h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              Food delivery platforms close your outlets without warning, costing you hundreds of dollars daily
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <Card className="border-red-200">
              <CardHeader>
                <AlertTriangle className="w-12 h-12 text-red-600 mb-4" />
                <CardTitle className="text-red-900">Silent Closures</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-gray-600">
                  GoFood and GrabFood automatically close outlets due to order cancellations, courier delays, or system
                  glitches - often without notification.
                </p>
              </CardContent>
            </Card>

            <Card className="border-orange-200">
              <CardHeader>
                <TrendingUp className="w-12 h-12 text-orange-600 mb-4" />
                <CardTitle className="text-orange-900">Revenue Loss</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-gray-600">
                  Each closure costs $70-200+ per day in lost orders. Owners often discover closures hours or even days
                  later.
                </p>
              </CardContent>
            </Card>

            <Card className="border-blue-200">
              <CardHeader>
                <Clock className="w-12 h-12 text-blue-600 mb-4" />
                <CardTitle className="text-blue-900">Late Discovery</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-gray-600">
                  Busy owners and unreliable staff monitoring means closures go unnoticed, compounding the financial
                  impact.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Solution Section */}
      <section className="py-16 px-4 bg-green-50">
        <div className="container mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              <span className="text-green-600">Automated Protection</span> for Your Business
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              We monitor your outlets every 15 minutes and alert you instantly when something goes wrong
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            <Card className="bg-white border-green-200">
              <CardHeader className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Shield className="w-8 h-8 text-green-600" />
                </div>
                <CardTitle className="text-lg">24/7 Monitoring</CardTitle>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-gray-600">
                  Automated checks every 15 minutes during operating hours on both GoFood and GrabFood
                </p>
              </CardContent>
            </Card>

            <Card className="bg-white border-green-200">
              <CardHeader className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Bell className="w-8 h-8 text-green-600" />
                </div>
                <CardTitle className="text-lg">Instant Alerts</CardTitle>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-gray-600">
                  WhatsApp, Telegram, email, and web push notifications within 5 minutes of status change
                </p>
              </CardContent>
            </Card>

            <Card className="bg-white border-green-200">
              <CardHeader className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Smartphone className="w-8 h-8 text-green-600" />
                </div>
                <CardTitle className="text-lg">Mobile Dashboard</CardTitle>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-gray-600">
                  Real-time status, historical data, and settings management from any device
                </p>
              </CardContent>
            </Card>

            <Card className="bg-white border-green-200">
              <CardHeader className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <TrendingUp className="w-8 h-8 text-green-600" />
                </div>
                <CardTitle className="text-lg">Revenue Protection</CardTitle>
              </CardHeader>
              <CardContent className="text-center">
                <p className="text-gray-600">
                  Prevent $70-200+ daily losses by catching closures within minutes, not hours
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 bg-green-600">
        <div className="container mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">Stop Losing Money to Silent Closures</h2>
          <p className="text-xl text-green-100 mb-8 max-w-2xl mx-auto">
            Join Bali's smartest F&B owners who protect their revenue with automated monitoring
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="/onboarding">
              <Button size="lg" className="bg-white text-green-600 hover:bg-gray-100 px-8 py-3">
                Start Free Trial - No Credit Card
              </Button>
            </Link>
            <Button
              size="lg"
              variant="outline"
              className="border-white text-white hover:bg-white hover:text-green-600 px-8 py-3 bg-transparent"
            >
              Schedule Demo Call
            </Button>
          </div>
          <p className="text-green-200 mt-4 text-sm">14-day free trial • Cancel anytime • Setup in 5 minutes</p>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 bg-gray-900">
        <div className="container mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between">
            <div className="flex items-center space-x-2 mb-4 md:mb-0">
              <div className="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
                <Bell className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-bold text-white">DeliveryTracker</span>
            </div>
            <div className="flex items-center space-x-6 text-gray-400">
              <Link href="#" className="hover:text-white transition-colors">
                Privacy
              </Link>
              <Link href="#" className="hover:text-white transition-colors">
                Terms
              </Link>
              <Link href="#" className="hover:text-white transition-colors">
                Support
              </Link>
            </div>
          </div>
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2024 DeliveryTracker. Protecting F&B businesses across Bali.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
