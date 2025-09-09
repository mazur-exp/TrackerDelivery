"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { Switch } from "@/components/ui/switch"
import { CheckCircle, XCircle, Plus, Settings, Bell, AlertTriangle, Smartphone, Mail, RefreshCw } from "lucide-react"
import Link from "next/link"

const initialStores = [
  {
    id: 1,
    name: "Warung Bali Asli",
    location: "Jl. Pantai Berawa, Canggu",
    gofoodStatus: "open",
    grabfoodStatus: "open",
    lastCheck: new Date(Date.now() - 2 * 60 * 1000), // 2 minutes ago
    nextCheck: new Date(Date.now() + 13 * 60 * 1000), // 13 minutes from now
    operatingHours: "10:00 - 22:00",
    uptimeToday: 100,
    alertsToday: 0,
    isActive: true,
  },
  {
    id: 2,
    name: "Healthy Bowl Co.",
    location: "Jl. Raya Seminyak, Seminyak",
    gofoodStatus: "open",
    grabfoodStatus: "open",
    lastCheck: new Date(Date.now() - 5 * 60 * 1000), // 5 minutes ago
    nextCheck: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes from now
    operatingHours: "08:00 - 21:00",
    uptimeToday: 100,
    alertsToday: 0,
    isActive: true,
  },
  {
    id: 3,
    name: "Café Sunset",
    location: "Jl. Kayu Aya, Seminyak",
    gofoodStatus: "closed",
    grabfoodStatus: "open",
    lastCheck: new Date(Date.now() - 23 * 60 * 1000), // 23 minutes ago
    nextCheck: new Date(Date.now() + 7 * 60 * 1000), // 7 minutes from now
    operatingHours: "09:00 - 23:00",
    uptimeToday: 87,
    alertsToday: 1,
    isActive: true,
    closureDetected: new Date(Date.now() - 23 * 60 * 1000),
  },
]

export default function DashboardPage() {
  const [stores, setStores] = useState(initialStores)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [notifications, setNotifications] = useState({
    whatsapp: { enabled: true, contact: "+62 812-3456-7890" },
    email: { enabled: true, contact: "owner@restaurant.com" },
    telegram: { enabled: false, contact: "" },
    webPush: { enabled: true, contact: "Browser" },
  })

  useEffect(() => {
    const interval = setInterval(() => {
      setStores((prevStores) =>
        prevStores.map((store) => ({
          ...store,
          nextCheck: new Date(store.nextCheck.getTime() - 1000),
        })),
      )
    }, 1000)

    return () => clearInterval(interval)
  }, [])

  const handleRefresh = async () => {
    setIsRefreshing(true)
    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 2000))

    setStores((prevStores) =>
      prevStores.map((store) => ({
        ...store,
        lastCheck: new Date(),
        nextCheck: new Date(Date.now() + 15 * 60 * 1000),
      })),
    )
    setIsRefreshing(false)
  }

  const formatTimeRemaining = (date) => {
    const now = new Date()
    const diff = Math.max(0, date.getTime() - now.getTime())
    const minutes = Math.floor(diff / 60000)
    const seconds = Math.floor((diff % 60000) / 1000)
    return `${minutes}:${seconds.toString().padStart(2, "0")}`
  }

  const formatTimeAgo = (date) => {
    const now = new Date()
    const diff = now.getTime() - date.getTime()
    const minutes = Math.floor(diff / 60000)
    if (minutes < 1) return "Just now"
    if (minutes === 1) return "1 min ago"
    return `${minutes} min ago`
  }

  const totalStores = stores.length
  const openStores = stores.filter((s) => s.gofoodStatus === "open" || s.grabfoodStatus === "open").length
  const totalAlertsToday = stores.reduce((sum, store) => sum + store.alertsToday, 0)
  const avgUptime = Math.round(stores.reduce((sum, store) => sum + store.uptimeToday, 0) / stores.length)

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
              <Bell className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-gray-900">DeliveryTracker</span>
          </Link>
          <div className="flex items-center space-x-3">
            <Button variant="ghost" size="sm" onClick={handleRefresh} disabled={isRefreshing}>
              <RefreshCw className={`w-4 h-4 mr-2 ${isRefreshing ? "animate-spin" : ""}`} />
              {isRefreshing ? "Checking..." : "Refresh"}
            </Button>
            <Button variant="ghost" size="sm">
              <Settings className="w-4 h-4 mr-2" />
              Settings
            </Button>
            <Link href="/onboarding">
              <Button size="sm" className="bg-green-600 hover:bg-green-700 text-white">
                <Plus className="w-4 h-4 mr-2" />
                Add Store
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Overview Cards */}
        <div className="grid md:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-gray-600">Total Stores</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-gray-900">{totalStores}</div>
              <p className="text-sm text-gray-500">All monitored</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-gray-600">Currently Open</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-600">{openStores}</div>
              <p className="text-sm text-gray-500">Accepting orders</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-gray-600">Alerts Today</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-orange-600">{totalAlertsToday}</div>
              <p className="text-sm text-gray-500">
                {totalAlertsToday === 1 ? "Closure detected" : "Closures detected"}
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-gray-600">Avg Uptime Today</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-blue-600">{avgUptime}%</div>
              <p className="text-sm text-gray-500">Above average</p>
            </CardContent>
          </Card>
        </div>

        <Tabs defaultValue="stores" className="space-y-6">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="stores">Store Status</TabsTrigger>
            <TabsTrigger value="history">History</TabsTrigger>
            <TabsTrigger value="notifications">Notifications</TabsTrigger>
          </TabsList>

          <TabsContent value="stores" className="space-y-6">
            {/* Store Status Cards */}
            <div className="grid gap-6">
              {stores.map((store) => (
                <Card
                  key={store.id}
                  className={`${
                    store.gofoodStatus === "closed" || store.grabfoodStatus === "closed"
                      ? "border-red-200 bg-red-50"
                      : "border-green-200 bg-green-50"
                  }`}
                >
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="flex items-center gap-2">
                          {store.gofoodStatus === "open" && store.grabfoodStatus === "open" ? (
                            <CheckCircle className="w-5 h-5 text-green-600" />
                          ) : (
                            <XCircle className="w-5 h-5 text-red-600" />
                          )}
                          {store.name}
                        </CardTitle>
                        <CardDescription>{store.location}</CardDescription>
                      </div>
                      <Badge
                        className={
                          store.gofoodStatus === "open" && store.grabfoodStatus === "open"
                            ? "bg-green-600 text-white"
                            : "bg-red-600 text-white"
                        }
                      >
                        {store.gofoodStatus === "open" && store.grabfoodStatus === "open" ? "Open" : "Issue Detected"}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="grid md:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">GoFood Status</span>
                          <span
                            className={`font-medium ${
                              store.gofoodStatus === "open" ? "text-green-600" : "text-red-600"
                            }`}
                          >
                            {store.gofoodStatus === "open" ? "Open" : "Closed"}
                          </span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">GrabFood Status</span>
                          <span
                            className={`font-medium ${
                              store.grabfoodStatus === "open" ? "text-green-600" : "text-red-600"
                            }`}
                          >
                            {store.grabfoodStatus === "open" ? "Open" : "Closed"}
                          </span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Last Check</span>
                          <span className="text-gray-900">{formatTimeAgo(store.lastCheck)}</span>
                        </div>
                      </div>
                      <div className="space-y-2">
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Operating Hours</span>
                          <span className="text-gray-900">{store.operatingHours}</span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Uptime Today</span>
                          <span className={`${store.uptimeToday === 100 ? "text-green-600" : "text-orange-600"}`}>
                            {store.uptimeToday}%
                          </span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Next Check</span>
                          <span className="text-gray-900 font-mono">{formatTimeRemaining(store.nextCheck)}</span>
                        </div>
                      </div>
                    </div>

                    <div className="mt-4">
                      <div className="flex justify-between text-sm mb-2">
                        <span className="text-gray-600">Today's Uptime</span>
                        <span className="text-gray-900">{store.uptimeToday}%</span>
                      </div>
                      <Progress value={store.uptimeToday} className="h-2" />
                    </div>

                    {(store.gofoodStatus === "closed" || store.grabfoodStatus === "closed") && (
                      <div className="mt-4 p-3 bg-red-100 rounded-lg">
                        <div className="flex items-center gap-2 text-red-800">
                          <AlertTriangle className="w-4 h-4" />
                          <span className="text-sm font-medium">Action Required</span>
                        </div>
                        <p className="text-sm text-red-700 mt-1">
                          {store.gofoodStatus === "closed" && store.grabfoodStatus === "closed"
                            ? "Both platforms show your store as closed."
                            : store.gofoodStatus === "closed"
                              ? "GoFood shows your store as closed."
                              : "GrabFood shows your store as closed."}{" "}
                          Check your tablet or contact platform support.
                        </p>
                        {store.closureDetected && (
                          <p className="text-xs text-red-600 mt-1">
                            Detected {formatTimeAgo(store.closureDetected)} • Alerts sent via WhatsApp, Email
                          </p>
                        )}
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="history" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Recent Status Changes</CardTitle>
                <CardDescription>Last 7 days of monitoring activity</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex items-center gap-4 p-3 bg-red-50 rounded-lg">
                    <XCircle className="w-5 h-5 text-red-600" />
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">Café Sunset - GoFood Closed</p>
                      <p className="text-sm text-gray-600">Today at 2:37 PM • Alert sent via WhatsApp, Email</p>
                    </div>
                    <Badge variant="destructive">Closed</Badge>
                  </div>

                  <div className="flex items-center gap-4 p-3 bg-green-50 rounded-lg">
                    <CheckCircle className="w-5 h-5 text-green-600" />
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">Healthy Bowl Co. - GrabFood Reopened</p>
                      <p className="text-sm text-gray-600">Yesterday at 8:15 AM • Automatic recovery</p>
                    </div>
                    <Badge className="bg-green-600 text-white">Open</Badge>
                  </div>

                  <div className="flex items-center gap-4 p-3 bg-red-50 rounded-lg">
                    <XCircle className="w-5 h-5 text-red-600" />
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">Healthy Bowl Co. - GrabFood Closed</p>
                      <p className="text-sm text-gray-600">Yesterday at 6:22 AM • Alert sent via Telegram</p>
                    </div>
                    <Badge variant="destructive">Closed</Badge>
                  </div>

                  <div className="flex items-center gap-4 p-3 bg-green-50 rounded-lg">
                    <CheckCircle className="w-5 h-5 text-green-600" />
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">Warung Bali Asli - All Platforms Online</p>
                      <p className="text-sm text-gray-600">2 days ago at 10:00 AM • Daily opening</p>
                    </div>
                    <Badge className="bg-green-600 text-white">Open</Badge>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="notifications" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Notification Settings</CardTitle>
                <CardDescription>Configure how and when you receive alerts</CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid md:grid-cols-2 gap-6">
                  <Card className="border-green-200">
                    <CardHeader>
                      <CardTitle className="text-lg flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Smartphone className="w-5 h-5 text-green-600" />
                          WhatsApp
                        </div>
                        <Switch
                          checked={notifications.whatsapp.enabled}
                          onCheckedChange={(checked) =>
                            setNotifications((prev) => ({
                              ...prev,
                              whatsapp: { ...prev.whatsapp, enabled: checked },
                            }))
                          }
                        />
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Status</span>
                          <Badge
                            className={
                              notifications.whatsapp.enabled ? "bg-green-600 text-white" : "bg-gray-400 text-white"
                            }
                          >
                            {notifications.whatsapp.enabled ? "Connected" : "Disabled"}
                          </Badge>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Phone</span>
                          <span className="text-sm text-gray-600">{notifications.whatsapp.contact}</span>
                        </div>
                        <Button variant="outline" size="sm" className="w-full bg-transparent">
                          Update Number
                        </Button>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="border-blue-200">
                    <CardHeader>
                      <CardTitle className="text-lg flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Mail className="w-5 h-5 text-blue-600" />
                          Email
                        </div>
                        <Switch
                          checked={notifications.email.enabled}
                          onCheckedChange={(checked) =>
                            setNotifications((prev) => ({
                              ...prev,
                              email: { ...prev.email, enabled: checked },
                            }))
                          }
                        />
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Status</span>
                          <Badge
                            className={
                              notifications.email.enabled ? "bg-green-600 text-white" : "bg-gray-400 text-white"
                            }
                          >
                            {notifications.email.enabled ? "Active" : "Disabled"}
                          </Badge>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Address</span>
                          <span className="text-sm text-gray-600">{notifications.email.contact}</span>
                        </div>
                        <Button variant="outline" size="sm" className="w-full bg-transparent">
                          Change Email
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                </div>

                <div className="pt-4 border-t">
                  <h4 className="font-medium text-gray-900 mb-3">Alert Preferences</h4>
                  <div className="space-y-4">
                    <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div>
                        <p className="font-medium">Store Closures</p>
                        <p className="text-sm text-gray-600">Get notified when a store unexpectedly closes</p>
                      </div>
                      <Switch defaultChecked />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div>
                        <p className="font-medium">Daily Summary</p>
                        <p className="text-sm text-gray-600">Receive daily uptime reports at 9 AM</p>
                      </div>
                      <Switch defaultChecked />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div>
                        <p className="font-medium">System Updates</p>
                        <p className="text-sm text-gray-600">Important service announcements</p>
                      </div>
                      <Switch />
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  )
}
