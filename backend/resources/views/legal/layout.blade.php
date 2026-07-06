<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Ludo Friends')</title>
    <style>
        :root {
            color-scheme: light;
            --bg: #f5f2ff;
            --card: #ffffff;
            --ink: #241d3d;
            --muted: #625b78;
            --primary: #5b3fd6;
            --border: #e3ddf4;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: Arial, Helvetica, sans-serif;
            line-height: 1.6;
            color: var(--ink);
            background: linear-gradient(180deg, #6a4ce0 0%, #8e6bff 260px, var(--bg) 260px);
        }

        .wrap {
            width: min(920px, calc(100% - 32px));
            margin: 0 auto;
            padding: 36px 0;
        }

        header {
            color: #ffffff;
            padding: 20px 0 30px;
        }

        header a {
            color: #ffffff;
            text-decoration: none;
            font-weight: 700;
        }

        .brand {
            font-size: 28px;
            font-weight: 800;
            margin: 0 0 8px;
        }

        .tagline {
            margin: 0;
            opacity: .88;
        }

        .card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 18px;
            padding: clamp(22px, 4vw, 42px);
            box-shadow: 0 18px 50px rgba(36, 29, 61, .14);
        }

        h1 {
            margin: 0 0 10px;
            line-height: 1.15;
            font-size: clamp(30px, 5vw, 44px);
        }

        h2 {
            margin: 28px 0 8px;
            font-size: 21px;
        }

        p {
            margin: 10px 0;
        }

        ul, ol {
            padding-left: 22px;
        }

        li {
            margin: 8px 0;
        }

        a {
            color: var(--primary);
        }

        .muted {
            color: var(--muted);
        }

        .links {
            display: grid;
            gap: 12px;
            grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
            margin-top: 24px;
        }

        .link-card {
            display: block;
            padding: 18px;
            border: 1px solid var(--border);
            border-radius: 14px;
            text-decoration: none;
            color: var(--ink);
            background: #fbfaff;
        }

        .link-card strong {
            display: block;
            color: var(--primary);
            margin-bottom: 4px;
        }

        footer {
            color: var(--muted);
            text-align: center;
            padding: 22px 0 0;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="wrap">
        <header>
            <a href="{{ url('/') }}" class="brand">Ludo Friends</a>
            <p class="tagline">Online and offline multiplayer board game.</p>
        </header>

        <main class="card">
            @yield('content')
        </main>

        <footer>
            <p>
                <a href="{{ url('/privacy') }}">Privacy Policy</a> |
                <a href="{{ url('/terms') }}">Terms</a> |
                <a href="{{ url('/data-deletion') }}">Data Deletion</a>
            </p>
        </footer>
    </div>
</body>
</html>
