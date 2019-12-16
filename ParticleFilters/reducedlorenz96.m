function dydt = reducedlorenz96(t, y, Q)
lorenz96out = lorenz96(t, Q*y);
dydt = Q' * lorenz96out;
end