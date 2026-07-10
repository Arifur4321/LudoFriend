@extends('legal.layout')

@section('title', 'Privacy Policy | Ludo Friends')

@section('content')
    <h1>Privacy Policy</h1>
    <p class="muted">Last updated: July 10, 2026</p>

    <p>
        This Privacy Policy explains how <strong>Ludo Friends</strong> (also
        referred to as “LudoFriend”, “we”, “us”) collects, uses, and protects
        information when you use the Ludo Friends mobile app and related backend
        services. If you have any questions, contact us at
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a>.
    </p>

    <h2>Who We Are</h2>
    <ul>
        <li><strong>App:</strong> Ludo Friends / LudoFriend</li>
        <li><strong>Developer / contact:</strong>
            <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a></li>
    </ul>

    <h2>Information We Collect</h2>
    <p>Ludo Friends supports guest login, email account login, Facebook Login,
        and Google Sign-In. Depending on how you play, we may collect:</p>
    <ul>
        <li>Your account name (chosen name or the name provided by your login).</li>
        <li>Your email address, if you register with email or if you sign in with
            Google and Google provides it. Email is optional and may be hidden
            depending on your login choice.</li>
        <li>If you sign in with <strong>Google</strong>: your Google profile id,
            name, profile photo, and email (when provided).</li>
        <li>If you sign in with <strong>Facebook</strong>: your Facebook public
            profile id, name, and profile photo. We request the
            <em>public_profile</em> permission only.</li>
        <li>Your in-app friend code and your in-app friends list.</li>
        <li>Gameplay data: rooms, match history, matchmaking, invites,
            leaderboard entries, statistics, and coins / wallet / in-game economy
            balances, plus purchase records if purchases are enabled.</li>
        <li>Device and app technical logs (such as app version, error and session
            information) needed for security, anti-cheat, and debugging.</li>
    </ul>

    <h2>Information We Do <em>Not</em> Collect</h2>
    <p>Unless a feature is explicitly added and disclosed in the future, Ludo
        Friends does <strong>not</strong> collect:</p>
    <ul>
        <li>Precise location data.</li>
        <li>Your phone contacts (no contacts upload).</li>
        <li>Microphone or camera data.</li>
        <li>Your Gmail inbox or email content (we do not use any Gmail
            mailbox access).</li>
        <li>Your Google Drive, Calendar, or Contacts data.</li>
        <li>Your full Facebook friends list — we do not request the
            <em>user_friends</em> permission.</li>
    </ul>

    <h2>How We Use Information</h2>
    <ul>
        <li>To sign you in and identify your account.</li>
        <li>To run multiplayer rooms and matchmaking.</li>
        <li>To power friends and invites.</li>
        <li>For gameplay, the leaderboard, anti-cheat, and account security.</li>
        <li>For support and debugging.</li>
    </ul>

    <h2>Sharing Of Data</h2>
    <ul>
        <li>We do <strong>not</strong> sell your personal data.</li>
        <li>Your data may be processed by infrastructure providers we use to run
            the app (for example, server hosting).</li>
        <li>When you use <strong>Facebook Login</strong>, that sign-in is provided
            by Meta.</li>
        <li>When you use <strong>Google Sign-In</strong>, that sign-in is provided
            by Google.</li>
        <li>Google Play may process install, purchase, and crash information
            separately under its own terms.</li>
    </ul>

    <h2>Data Retention</h2>
    <p>We keep account and game data while your account exists and as needed to
        operate the game, maintain fair play, and meet legal or technical
        requirements. You can request deletion by email or through the in-app
        deletion flow; see our
        <a href="{{ url('/data-deletion') }}">Data Deletion</a> page.</p>

    <h2>Security</h2>
    <ul>
        <li>Our API is served over HTTPS.</li>
        <li>API requests are authenticated with per-device tokens.</li>
        <li>Multiplayer is server-authoritative — the server validates game
            actions to protect fair play.</li>
    </ul>

    <h2>Children</h2>
    <p>Ludo Friends is not directed to children where such use is not permitted,
        and we do not knowingly collect personal data from children in those
        cases. If you believe a child has provided us personal data, contact
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a> and we
        will remove it. If the app is later directed to children, additional
        Google Play “Families” requirements may apply.</p>

    <h2>Your Rights &amp; Deletion</h2>
    <p>You may request access to or deletion of your data by emailing
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a>. We aim
        to action deletion requests within <strong>30 days</strong>. See the
        <a href="{{ url('/data-deletion') }}">Data Deletion</a> page for the full
        process, including how to remove the app from your Facebook account and
        how to disconnect it from your Google account.</p>

    <h2>Contact</h2>
    <p>For privacy questions or deletion requests, email
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a>.</p>
@endsection
