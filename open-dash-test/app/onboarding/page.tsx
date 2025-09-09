"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  CheckCircle,
  ArrowRight,
  Bell,
  Smartphone,
  Mail,
  ArrowLeft,
  AlertCircle,
  Loader2,
  MessageCircle,
} from "lucide-react"
import Link from "next/link"

export default function OnboardingPage() {
  const [step, setStep] = useState(1)
  const [isLoading, setIsLoading] = useState(false)
  const [storeData, setStoreData] = useState({
    name: "",
    location: "",
    gofoodUrl: "",
    grabfoodUrl: "",
    operatingHours: "10:00 - 22:00",
  })
  const [notifications, setNotifications] = useState({
    whatsapp: "",
    telegram: "",
    email: "",
  })
  const [errors, setErrors] = useState({})

  const validateUrl = (url, platform) => {
    if (!url) return true // Optional field

    const patterns = {
      gofood: /^https:\/\/gofood\.link\/a\/[a-zA-Z0-9]+$/,
      grabfood: /^https:\/\/r\.grab\.com\/g\/[a-zA-Z0-9_-]+$/,
    }
    return patterns[platform]?.test(url) || false
  }

  const handleNext = async () => {
    setErrors({})

    if (step === 1) {
      const newErrors = {}
      if (!storeData.gofoodUrl) {
        newErrors.gofoodUrl = "GoFood URL is required"
      } else if (!validateUrl(storeData.gofoodUrl, "gofood")) {
        newErrors.gofoodUrl = "Please enter a valid GoFood restaurant URL"
      }

      if (storeData.grabfoodUrl && !validateUrl(storeData.grabfoodUrl, "grabfood")) {
        newErrors.grabfoodUrl = "Please enter a valid GrabFood restaurant URL"
      }

      if (Object.keys(newErrors).length > 0) {
        setErrors(newErrors)
        return
      }

      setIsLoading(true)
      await new Promise((resolve) => setTimeout(resolve, 2000))
      setStoreData((prev) => ({
        ...prev,
        name: "Warung Bali Asli",
        location: "Jl. Pantai Berawa, Canggu, Bali",
      }))
      setIsLoading(false)
    }

    if (step === 3) {
      const newErrors = {}
      if (!notifications.whatsapp && !notifications.telegram && !notifications.email) {
        newErrors.notifications = "Please provide at least one notification method"
      }
      if (notifications.email && !/\S+@\S+\.\S+/.test(notifications.email)) {
        newErrors.email = "Please enter a valid email address"
      }

      if (Object.keys(newErrors).length > 0) {
        setErrors(newErrors)
        return
      }

      setIsLoading(true)
      await new Promise((resolve) => setTimeout(resolve, 2000))
      window.location.href = "/dashboard"
      return
    }

    if (step < 3) setStep(step + 1)
  }

  const handlePrevious = () => {
    if (step > 1) setStep(step - 1)
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-white">
      <header className="border-b bg-white/80 backdrop-blur-sm">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
              <Bell className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-gray-900">DeliveryTracker</span>
          </Link>
          <Badge className="bg-green-100 text-green-800 border-green-200">Setup Progress: {step}/3</Badge>
        </div>
      </header>

      <div className="container mx-auto px-4 py-12">
        <div className="max-w-2xl mx-auto">
          <div className="flex items-center justify-center mb-12">
            <div className="flex items-center space-x-4">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  step >= 1 ? "bg-green-600 text-white" : "bg-gray-200 text-gray-600"
                }`}
              >
                {step > 1 ? <CheckCircle className="w-6 h-6" /> : "1"}
              </div>
              <div className={`w-16 h-1 ${step >= 2 ? "bg-green-600" : "bg-gray-200"}`} />
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  step >= 2 ? "bg-green-600 text-white" : "bg-gray-200 text-gray-600"
                }`}
              >
                {step > 2 ? <CheckCircle className="w-6 h-6" /> : "2"}
              </div>
              <div className={`w-16 h-1 ${step >= 3 ? "bg-green-600" : "bg-gray-200"}`} />
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  step >= 3 ? "bg-green-600 text-white" : "bg-gray-200 text-gray-600"
                }`}
              >
                {step > 3 ? <CheckCircle className="w-6 h-6" /> : "3"}
              </div>
            </div>
          </div>

          {step === 1 && (
            <Card>
              <CardHeader className="text-center">
                <CardTitle className="text-2xl">Add Your First Store</CardTitle>
                <CardDescription>
                  Let's start monitoring your delivery platforms. We'll need your store URLs from GoFood and GrabFood.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="gofood-url">GoFood Store URL *</Label>
                  <Input
                    id="gofood-url"
                    placeholder="https://gofood.link/a/Jkk6Xoml"
                    value={storeData.gofoodUrl}
                    onChange={(e) => setStoreData({ ...storeData, gofoodUrl: e.target.value })}
                    className={errors.gofoodUrl ? "border-red-500" : ""}
                  />
                  {errors.gofoodUrl && <p className="text-sm text-red-600">{errors.gofoodUrl}</p>}
                  <p className="text-sm text-gray-600">
                    Copy the URL from your GoFood store page (format: gofood.link/a/...)
                  </p>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="grabfood-url">GrabFood Store URL (Optional)</Label>
                  <Input
                    id="grabfood-url"
                    placeholder="https://r.grab.com/g/6-20250909_122536_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4KZFF42EN2VGT"
                    value={storeData.grabfoodUrl}
                    onChange={(e) => setStoreData({ ...storeData, grabfoodUrl: e.target.value })}
                    className={errors.grabfoodUrl ? "border-red-500" : ""}
                  />
                  {errors.grabfoodUrl && <p className="text-sm text-red-600">{errors.grabfoodUrl}</p>}
                  <p className="text-sm text-gray-600">
                    Add your GrabFood URL if you're also on their platform (format: r.grab.com/g/...)
                  </p>
                </div>

                <Alert>
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription>
                    <strong>How to find your store URLs:</strong>
                    <br />• <strong>GoFood:</strong> Open your store in GoFood app → Share → Copy link (should start
                    with gofood.link/a/)
                    <br />• <strong>GrabFood:</strong> Open your store in GrabFood app → Share → Copy link (should start
                    with r.grab.com/g/)
                    <br />
                    <strong>Valid examples:</strong>
                    <br />• GoFood: https://gofood.link/a/Jkk6Xoml
                    <br />• GrabFood:
                    https://r.grab.com/g/6-20250909_122536_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4KZFF42EN2VGT
                  </AlertDescription>
                </Alert>

                <Button
                  onClick={handleNext}
                  className="w-full bg-green-600 hover:bg-green-700 text-white"
                  disabled={isLoading}
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Processing URLs...
                    </>
                  ) : (
                    <>
                      Continue
                      <ArrowRight className="w-4 h-4 ml-2" />
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>
          )}

          {step === 2 && (
            <Card>
              <CardHeader className="text-center">
                <CardTitle className="text-2xl">Verify Store Information</CardTitle>
                <CardDescription>We've extracted your store details. Please confirm they're correct.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="bg-green-50 p-6 rounded-lg border border-green-200">
                  <div className="flex items-center gap-2 mb-4">
                    <CheckCircle className="w-5 h-5 text-green-600" />
                    <span className="font-medium text-green-900">Store Details Extracted Successfully</span>
                  </div>

                  <div className="space-y-4">
                    <div>
                      <Label className="text-sm font-medium text-gray-700">Store Name</Label>
                      <Input
                        value={storeData.name}
                        onChange={(e) => setStoreData({ ...storeData, name: e.target.value })}
                        className="mt-1"
                      />
                    </div>

                    <div>
                      <Label className="text-sm font-medium text-gray-700">Location</Label>
                      <Input
                        value={storeData.location}
                        onChange={(e) => setStoreData({ ...storeData, location: e.target.value })}
                        className="mt-1"
                      />
                    </div>

                    <div>
                      <Label className="text-sm font-medium text-gray-700">Operating Hours</Label>
                      <Input
                        value={storeData.operatingHours}
                        onChange={(e) => setStoreData({ ...storeData, operatingHours: e.target.value })}
                        className="mt-1"
                      />
                      <p className="text-xs text-gray-600 mt-1">We'll only monitor during these hours</p>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label className="text-sm font-medium text-gray-700">GoFood</Label>
                        <div className="mt-1 p-2 bg-white rounded border">
                          <Badge className="bg-green-600 text-white">Connected</Badge>
                        </div>
                      </div>
                      <div>
                        <Label className="text-sm font-medium text-gray-700">GrabFood</Label>
                        <div className="mt-1 p-2 bg-white rounded border">
                          {storeData.grabfoodUrl ? (
                            <Badge className="bg-green-600 text-white">Connected</Badge>
                          ) : (
                            <Badge variant="outline">Not Added</Badge>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <Button variant="outline" onClick={handlePrevious} className="flex-1 bg-transparent">
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back
                  </Button>
                  <Button onClick={handleNext} className="flex-1 bg-green-600 hover:bg-green-700 text-white">
                    Looks Good
                    <ArrowRight className="w-4 h-4 ml-2" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}

          {step === 3 && (
            <Card>
              <CardHeader className="text-center">
                <CardTitle className="text-2xl">Setup Notifications</CardTitle>
                <CardDescription>Choose how you want to receive alerts when your store status changes.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                {errors.notifications && (
                  <Alert variant="destructive">
                    <AlertCircle className="h-4 w-4" />
                    <AlertDescription>{errors.notifications}</AlertDescription>
                  </Alert>
                )}

                <div className="grid gap-4">
                  <Card className="border-green-200 bg-green-50">
                    <CardHeader className="pb-3">
                      <CardTitle className="text-lg flex items-center gap-2">
                        <Smartphone className="w-5 h-5 text-green-600" />
                        WhatsApp (Recommended)
                      </CardTitle>
                      <CardDescription>Get instant alerts on your phone</CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div>
                          <Label htmlFor="whatsapp">WhatsApp Number</Label>
                          <Input
                            id="whatsapp"
                            placeholder="+62 812-3456-7890"
                            className="mt-1"
                            value={notifications.whatsapp}
                            onChange={(e) => setNotifications({ ...notifications, whatsapp: e.target.value })}
                          />
                        </div>
                        <Badge className="bg-green-600 text-white">Most Reliable</Badge>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="border-blue-200 bg-blue-50">
                    <CardHeader className="pb-3">
                      <CardTitle className="text-lg flex items-center gap-2">
                        <MessageCircle className="w-5 h-5 text-blue-600" />
                        Telegram
                      </CardTitle>
                      <CardDescription>Fast notifications via Telegram bot</CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div>
                          <Label htmlFor="telegram">Telegram Username</Label>
                          <Input
                            id="telegram"
                            placeholder="@yourusername"
                            className="mt-1"
                            value={notifications.telegram}
                            onChange={(e) => setNotifications({ ...notifications, telegram: e.target.value })}
                          />
                          <p className="text-xs text-gray-600 mt-1">Start with @ (e.g., @johndoe)</p>
                        </div>
                        <Badge className="bg-blue-600 text-white">Instant Delivery</Badge>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="border-gray-200">
                    <CardHeader className="pb-3">
                      <CardTitle className="text-lg flex items-center gap-2">
                        <Mail className="w-5 h-5 text-gray-600" />
                        Email Notifications
                      </CardTitle>
                      <CardDescription>Backup alerts via email</CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div>
                          <Label htmlFor="email">Email Address</Label>
                          <Input
                            id="email"
                            type="email"
                            placeholder="owner@restaurant.com"
                            className={`mt-1 ${errors.email ? "border-red-500" : ""}`}
                            value={notifications.email}
                            onChange={(e) => setNotifications({ ...notifications, email: e.target.value })}
                          />
                          {errors.email && <p className="text-sm text-red-600 mt-1">{errors.email}</p>}
                        </div>
                        <Badge variant="outline">Always Enabled</Badge>
                      </div>
                    </CardContent>
                  </Card>
                </div>

                <Alert>
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription>
                    <strong>💡 Pro Tip:</strong> We recommend setting up WhatsApp or Telegram for the fastest alerts.
                    You can always add more notification methods later in your dashboard.
                  </AlertDescription>
                </Alert>

                <div className="flex gap-3">
                  <Button variant="outline" onClick={handlePrevious} className="flex-1 bg-transparent">
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back
                  </Button>
                  <Button
                    onClick={handleNext}
                    className="flex-1 bg-green-600 hover:bg-green-700 text-white"
                    disabled={isLoading}
                  >
                    {isLoading ? (
                      <>
                        <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                        Setting up...
                      </>
                    ) : (
                      <>
                        Start Monitoring
                        <CheckCircle className="w-4 h-4 ml-2" />
                      </>
                    )}
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}
