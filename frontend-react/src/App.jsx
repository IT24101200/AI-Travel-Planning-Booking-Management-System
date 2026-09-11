import { useCallback, useMemo, useState } from 'react'
import { Route, Routes, useLocation } from 'react-router-dom'
import { Backdrop } from './components/background/Backdrop.jsx'
import { Navbar } from './components/layout/Navbar.jsx'
import { Footer } from './components/layout/Footer.jsx'
import { ScrollToTop } from './components/layout/ScrollToTop.jsx'
import { SceneContext } from './lib/sceneContext.js'
import { AuthProvider } from './lib/auth.jsx'
import { RequireAuth } from './components/auth/RequireAuth.jsx'
import { StaffLayout } from './components/layout/StaffLayout.jsx'
import { featuredIds } from './data/destinations.js'
import { useWeatherTheme } from './lib/useWeatherTheme.js'
import Home from './pages/site/Home.jsx'
import Destinations from './pages/site/Destinations.jsx'
import DestinationDetail from './pages/site/DestinationDetail.jsx'
import Experiences from './pages/site/Experiences.jsx'
import Planner from './pages/site/Planner.jsx'
import About from './pages/site/About.jsx'
import Contact from './pages/site/Contact.jsx'
import NotFound from './pages/site/NotFound.jsx'
import Login from './pages/auth/Login.jsx'
import CustomerDirectory from './pages/customers/CustomerDirectory.jsx'
import NotificationLogs from './pages/customers/NotificationLogs.jsx'
import TourCatalogManagement from './pages/tours/TourCatalogManagement.jsx'
import ItineraryReview from './pages/tours/ItineraryReview.jsx'
import HotelVendorManagement from './pages/hotels/HotelVendorManagement.jsx'
import TransportFleetManagement from './pages/hotels/TransportFleetManagement.jsx'
import BookingApprovalDashboard from './pages/bookings/BookingApprovalDashboard.jsx'
import PaymentsRevenueReport from './pages/bookings/PaymentsRevenueReport.jsx'

/**
 * Public marketing site + staff console.
 * - SceneContext shares the active destination between cards, hero and backdrop.
 * - useWeatherTheme is lifted here so the hero AND the backdrop dim together.
 * - /staff/* is JWT-guarded (RequireAuth) per the master doc: React = staff/admin.
 */
export default function App() {
  const [scene, setScene] = useState({ activeId: featuredIds[0], leavingId: null })
  const { pathname } = useLocation()
  const weatherTheme = useWeatherTheme()
  const isStaffRoute = pathname.startsWith('/staff')
  const timeOfDay = weatherTheme?.timeOfDay || 'morning'

  const setActiveId = useCallback((id) => {
    setScene((prev) => (prev.activeId === id ? prev : { activeId: id, leavingId: prev.activeId }))
  }, [])

  const value = useMemo(
    () => ({
      activeId: scene.activeId,
      setActiveId,
    }),
    [scene.activeId, setActiveId],
  )

  return (
    <AuthProvider>
      <SceneContext.Provider value={value}>
        <a className="skip-link" href="#main">
          Skip to content
        </a>

        <Backdrop
          activeId={scene.activeId}
          leavingId={scene.leavingId}
          calm={pathname !== '/'}
          weather={weatherTheme?.weather}
          timeOfDay={timeOfDay}
        />
        <ScrollToTop />
        <Navbar />

        <main id="main">
          <Routes>
            <Route path="/" element={<Home weatherTheme={weatherTheme} />} />
            <Route path="/destinations" element={<Destinations />} />
            <Route path="/destinations/:id" element={<DestinationDetail />} />
            <Route path="/experiences" element={<Experiences />} />
            <Route path="/planner" element={<Planner />} />
            <Route path="/about" element={<About />} />
            <Route path="/contact" element={<Contact />} />
            <Route path="/login" element={<Login />} />

            <Route
              path="/staff"
              element={
                <RequireAuth roles={['staff', 'admin', 'agent']}>
                  <StaffLayout />
                </RequireAuth>
              }
            >
              <Route index element={<BookingApprovalDashboard />} />
              <Route path="bookings" element={<BookingApprovalDashboard />} />
              <Route path="payments" element={<PaymentsRevenueReport />} />
              <Route path="customers" element={<CustomerDirectory />} />
              <Route path="notifications" element={<NotificationLogs />} />
              <Route path="tours" element={<TourCatalogManagement />} />
              <Route path="itineraries" element={<ItineraryReview />} />
              <Route path="hotels" element={<HotelVendorManagement />} />
              <Route path="transport" element={<TransportFleetManagement />} />
            </Route>

            <Route path="*" element={<NotFound />} />
          </Routes>
        </main>

        {!isStaffRoute && <Footer />}
      </SceneContext.Provider>
    </AuthProvider>
  )
}
