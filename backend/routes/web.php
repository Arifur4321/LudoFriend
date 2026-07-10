<?php

use Illuminate\Support\Facades\Route;

Route::view('/', 'legal.index')->name('legal.home');
Route::view('/privacy', 'legal.privacy')->name('legal.privacy');
Route::view('/terms', 'legal.terms')->name('legal.terms');
Route::view('/data-deletion', 'legal.data-deletion')->name('legal.data-deletion');
Route::view('/support', 'legal.support')->name('legal.support');
