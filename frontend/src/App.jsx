import { useState, useEffect } from 'react'

const API_URL = 'http://127.0.0.1:8000/api/v1'

const STATUS_PROGRESS = {
  'pending': 10,
  'generating': 30,
  'compiling': 60,
  'backtesting': 85,
  'completed': 100,
  'failed': 100
}

function App() {
  const [token, setToken] = useState(localStorage.getItem('smartTradeToken') || '')
  const [username, setUsername] = useState(localStorage.getItem('smartTradeUser') || '')
  const [isLogin, setIsLogin] = useState(true)

  // Auth form state
  const [authUsername, setAuthUsername] = useState('')
  const [authEmail, setAuthEmail] = useState('')
  const [authPassword, setAuthPassword] = useState('')
  const [authError, setAuthError] = useState('')
  const [authLoading, setAuthLoading] = useState(false)

  // Main app state
  const [prompt, setPrompt] = useState('')
  const [loading, setLoading] = useState(false)
  const [jobs, setJobs] = useState([])

  const authHeaders = () => ({
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  })

  // Load job history from backend on login
  useEffect(() => {
    if (!token) return
    fetchHistory()
  }, [token])

  const fetchHistory = async () => {
    try {
      const res = await fetch(`${API_URL}/results/history`, {
        headers: authHeaders()
      })
      if (res.ok) {
        const data = await res.json()
        setJobs(data)
      } else if (res.status === 401) {
        handleLogout()
      }
    } catch (e) {
      console.error("Failed to fetch history", e)
    }
  }

  // Polling logic
  useEffect(() => {
    if (!token) return
    const activeJobs = jobs.filter(j => j.status !== 'completed' && j.status !== 'failed')
    if (activeJobs.length === 0) return

    const intervalId = setInterval(async () => {
      const updatedJobs = await Promise.all(
        jobs.map(async (job) => {
          if (job.status === 'completed' || job.status === 'failed') return job
          try {
            const res = await fetch(`${API_URL}/results/${job.job_id}`, {
              headers: authHeaders()
            })
            if (res.ok) {
              const data = await res.json()
              return { ...job, ...data }
            }
          } catch (e) {
            console.error("Poll failed", e)
          }
          return job
        })
      )
      setJobs(updatedJobs)
    }, 2000)

    return () => clearInterval(intervalId)
  }, [jobs, token])

  // ── Auth handlers ──────────────────────────────────────────────────
  const handleAuth = async (e) => {
    e.preventDefault()
    setAuthError('')
    setAuthLoading(true)

    const endpoint = isLogin ? '/auth/login' : '/auth/register'
    const body = isLogin
      ? { username: authUsername, password: authPassword }
      : { username: authUsername, email: authEmail, password: authPassword }

    try {
      const res = await fetch(`${API_URL}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      })
      const data = await res.json()
      if (res.ok) {
        localStorage.setItem('smartTradeToken', data.token)
        localStorage.setItem('smartTradeUser', data.username)
        setToken(data.token)
        setUsername(data.username)
        setAuthUsername('')
        setAuthEmail('')
        setAuthPassword('')
      } else {
        setAuthError(data.detail || 'Authentication failed')
      }
    } catch (err) {
      setAuthError('Cannot connect to server')
    } finally {
      setAuthLoading(false)
    }
  }

  const handleLogout = () => {
    localStorage.removeItem('smartTradeToken')
    localStorage.removeItem('smartTradeUser')
    setToken('')
    setUsername('')
    setJobs([])
  }

  // ── Strategy submit ────────────────────────────────────────────────
  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!prompt.trim()) return

    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/generate`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ prompt })
      })
      if (res.ok) {
        const data = await res.json()
        const newJob = {
          job_id: data.job_id,
          status: 'pending',
          prompt: prompt,
        }
        setJobs(prev => [newJob, ...prev])
        setPrompt('')
      } else if (res.status === 401) {
        handleLogout()
      }
    } catch (error) {
      alert("Failed to connect to the backend!")
    } finally {
      setLoading(false)
    }
  }

  // ── RENDER: Auth Screen ────────────────────────────────────────────
  if (!token) {
    return (
      <div className="app-container">
        <div className="glass-card auth-card">
          <h1>SmartTrade</h1>
          <p className="subtitle">AI-Powered MQL5 Expert Advisor Generator</p>

          <div className="auth-toggle">
            <button
              className={`toggle-btn ${isLogin ? 'active' : ''}`}
              onClick={() => { setIsLogin(true); setAuthError('') }}
            >Login</button>
            <button
              className={`toggle-btn ${!isLogin ? 'active' : ''}`}
              onClick={() => { setIsLogin(false); setAuthError('') }}
            >Register</button>
          </div>

          <form onSubmit={handleAuth} className="auth-form">
            <input
              type="text"
              placeholder="Username"
              value={authUsername}
              onChange={(e) => setAuthUsername(e.target.value)}
              required
            />
            {!isLogin && (
              <input
                type="email"
                placeholder="Email"
                value={authEmail}
                onChange={(e) => setAuthEmail(e.target.value)}
                required
              />
            )}
            <input
              type="password"
              placeholder="Password"
              value={authPassword}
              onChange={(e) => setAuthPassword(e.target.value)}
              required
              minLength={8}
            />
            {!isLogin && (
              <p className="password-hint">
                Min 8 characters: at least 1 letter, 1 number, 1 special character
              </p>
            )}
            {authError && <p className="auth-error">{authError}</p>}
            <button type="submit" disabled={authLoading}>
              {authLoading ? 'Please wait...' : (isLogin ? 'Sign In' : 'Create Account')}
            </button>
          </form>
        </div>
      </div>
    )
  }

  // ── RENDER: Main App ───────────────────────────────────────────────
  return (
    <div className="app-container">
      <div className="glass-card header">
        <div className="top-bar">
          <div>
            <h1>SmartTrade</h1>
            <p className="subtitle">Welcome back, <strong>{username}</strong></p>
          </div>
          <button className="logout-btn" onClick={handleLogout}>Logout</button>
        </div>

        <form onSubmit={handleSubmit} className="input-container">
          <textarea
            placeholder="Describe your trading strategy... (e.g. 'Buy when 50 SMA crosses above 200 SMA')"
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            disabled={loading}
          />
          <button type="submit" disabled={loading || !prompt.trim()}>
            {loading ? 'Submitting...' : 'Generate AI Strategy'}
          </button>
        </form>
      </div>

      {jobs.length > 0 && (
        <div className="history-section">
          <h2 style={{ paddingLeft: '10px' }}>Your Algorithms <span className="script-count">({jobs.length}/5)</span></h2>
          {jobs.map(job => (
            <div key={job.job_id} className="glass-card job-card">
              <div className="job-header">
                <div>
                  <span className="job-id">ID: {job.job_id.substring(0, 8)}...</span>
                  <div style={{ fontSize: '0.9rem', marginTop: '5px', opacity: 0.8 }}>
                    <strong>Prompt:</strong> {job.prompt}
                  </div>
                </div>
                <span className={`status-badge status-${job.status}`}>
                  {job.status.replace('_', ' ')}
                </span>
              </div>

              {job.status !== 'completed' && job.status !== 'failed' && (
                <div className="progress-track">
                  <div
                    className="progress-bar pulsing"
                    style={{ width: `${STATUS_PROGRESS[job.status] || 0}%` }}
                  ></div>
                </div>
              )}

              {job.status === 'failed' && job.compile_log && (
                <div className="code-block error-log">
                  <strong>Compilation Failed:</strong><br/>
                  {job.compile_log}
                </div>
              )}

              {job.status === 'completed' && job.script_content && (
                <div>
                  {job.backtest_result && (
                    <div style={{ marginBottom: '15px', background: 'rgba(16, 185, 129, 0.1)', padding: '10px', borderRadius: '8px' }}>
                      <strong style={{ color: '#10b981' }}>Backtest Metrics:</strong>
                      <pre style={{ marginTop: '5px', fontSize: '0.85rem' }}>{job.backtest_result}</pre>
                    </div>
                  )}
                  <h4 style={{ marginBottom: '10px' }}>MQL5 Source Code:</h4>
                  <div className="code-block">
                    {job.script_content}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default App
