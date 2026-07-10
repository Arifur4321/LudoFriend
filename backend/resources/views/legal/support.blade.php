@extends('legal.layout')

@section('title', 'Support | Ludo Friends')

@section('content')
    <h1>Support</h1>
    <p class="muted">Last updated: July 10, 2026</p>

    <p>
        Need help with <strong>Ludo Friends</strong>? We’re happy to help with
        account, login, gameplay, or data questions.
    </p>

    <h2>Contact</h2>
    <ul>
        <li><strong>Email:</strong>
            <a href="mailto:hatbazar627@gmail.com">hatbazar627@gmail.com</a></li>
    </ul>
    <p>When you write to us, please include your account name and, if relevant,
        which login you used (guest, email, Facebook, or Google). This helps us
        find your account faster.</p>

    <h2>Common Links</h2>
    <ul>
        <li><a href="{{ url('/privacy') }}">Privacy Policy</a></li>
        <li><a href="{{ url('/terms') }}">Terms of Service</a></li>
        <li><a href="{{ url('/data-deletion') }}">Data Deletion</a></li>
    </ul>
@endsection
