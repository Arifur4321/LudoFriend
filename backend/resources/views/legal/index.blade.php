@extends('legal.layout')

@section('title', 'Ludo Friends Legal')

@section('content')
    <h1>Ludo Friends</h1>
    <p class="muted">Public information for players, app stores, and platform review.</p>
    <p>
        Ludo Friends is an online and offline multiplayer board game. Use the links
        below to review our legal and data deletion information.
    </p>

    <div class="links">
        <a class="link-card" href="{{ url('/privacy') }}">
            <strong>Privacy Policy</strong>
            Learn what data may be collected and how it is used.
        </a>
        <a class="link-card" href="{{ url('/terms') }}">
            <strong>Terms</strong>
            Review fair-use, virtual coins, and service terms.
        </a>
        <a class="link-card" href="{{ url('/data-deletion') }}">
            <strong>Data Deletion</strong>
            Request deletion, or remove the app from Facebook or Google.
        </a>
        <a class="link-card" href="{{ url('/support') }}">
            <strong>Support</strong>
            Get help with your account, login, or gameplay.
        </a>
    </div>
@endsection
