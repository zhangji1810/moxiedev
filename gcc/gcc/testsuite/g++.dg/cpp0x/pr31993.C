// { dg-options "-std=c++0x" }

template<typename...> struct A;

template<template<int> class... T> struct A<T<0>...>
{
  template<int> struct B {};
  B<0> b;
};
