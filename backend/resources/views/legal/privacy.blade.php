@extends('legal.layout')

@section('title', 'Privacy Policy | Ludo Friends')

@section('content')
    <h1>Privacy Policy</h1>
    <p class="muted">Last updated: July 6, 2026</p>

    <p>
        This Privacy Policy explains how Ludo Friends collects, uses, and protects
        information when you use the Ludo Friends mobile app and related services.
        If you have questions, contact us at
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a>.
    </p>

    <h2>Information We May Collect</h2>
    <p>
        Ludo Friends supports account login, guest login, and Facebook Login. The
        information we may collect includes:
    </p>
    <ul>
        <li>Name and email address if provided by Facebook or by you.</li>
        <li>Facebook user ID and profile/avatar if provided through Facebook Login.</li>
        <li>Game profile information, coins, rooms, match history, leaderboard entries, and statistics.</li>
        <li>Device, session, authentication, and security information needed to operate the app.</li>
        <li>Support requests, reports, and moderation information you submit.</li>
    </ul>

    <h2>How We Use Information</h2>
    <p>
        We use information to provide login, gameplay, matchmaking, friends and
        room invites, leaderboard features, account security, abuse prevention,
        app support, and service improvement.
    </p>

    <h2>Sharing And Sale Of Data</h2>
    <p>
        We do not sell your personal data. We may use third-party providers to
        operate the app, including Meta/Facebook Login, server hosting providers,
        and Google Play or App Store payment systems if purchases are enabled in
        the future.
    </p>

    <h2>Data Retention And Deletion</h2>
    <p>
        We keep information as needed to operate the game, protect accounts,
        maintain fair play, and satisfy legal or technical requirements. You may
        request deletion by contacting
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a> or by
        following the instructions on our
        <a href="{{ url('/data-deletion') }}">Data Deletion</a> page.
    </p>

    <h2>Contact</h2>
    <p>
        For privacy questions or deletion requests, email
        <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a>.
    </p>
@endsection
