clc;
clear;

%Model parameters

%Numero de variables de estado
nx = 4;

%Numero de entradas
nu = 2;

%Numero de salidas
ny = 2;

%Area de los tanques
A = 4.9; %cm2

a = 0.03;

%Constante para pasar de voltaje a flujo
k = 1.6;

%Fraccion de agua que va a cada tanque
gamma = 0.3;

%Ganancia del sensor para medir la altura de los tanques
kc = 0.5;

%Gravedad
g = 981;

% Puntos de equilibrio
h1e = 10;
h2e = 10;

% Ecuaciones
syms h3e h4e u1e u2e
eq1 = -(a/A)*sqrt(2*g*h1e) + (a/A)*sqrt(2*g*h3e) + (gamma*k/A)*u1e == 0;
eq2 = -(a/A)*sqrt(2*g*h2e) + (a/A)*sqrt(2*g*h4e) + (gamma*k/A)*u2e == 0;
eq3 = -(a/A)*sqrt(2*g*h3e) + ((1-gamma)*k/A)*u2e == 0; 
eq4 = -(a/A)*sqrt(2*g*h4e) + ((1-gamma)*k/A)*u1e == 0; 

sol = solve([eq1, eq2, eq3, eq4], [h3e, h4e, u1e, u2e]);

%% Puntos de Equilibrio
h3e = double(sol.h3e);
h4e = double(sol.h4e);
u1e = double(sol.u1e);
u2e = double(sol.u2e);

hequils = [h1e; h2e; h3e; h4e];

%% Modelo Lineal de tiempo continuo
T1 = (A/a)*sqrt(2*h1e/g);
T2 = (A/a)*sqrt(2*h2e/g);
T3 = (A/a)*sqrt(2*h3e/g);
T4 = (A/a)*sqrt(2*h4e/g);

A_matriz = [-1/T1, 0, 1/T3, 0; 0, -1/T2, 0, 1/T4; 0, 0, -1/T3, 0; 0, 0, 0, -1/T4];
B_matriz = [gamma*k/A, 0; 0, gamma*k/A; 0, (1-gamma)*k/A; (1-gamma)*k/A, 0];
C_matriz = [kc, 0, 0, 0; 0, kc, 0, 0];
D_matriz = zeros(ny, nu);

%% Modelo lineal de tiempo discreto
ct_sys = ss(A_matriz, B_matriz, C_matriz, D_matriz); %Sistema usando ss (state space)
Ts = 2; %Tiempo de muestreo

dt_sys = c2d(ct_sys, Ts); %Pasar el modelo a tiempo discreto

A_matriz_dt = dt_sys.A;
B_matriz_dt = dt_sys.B;
C_matriz_dt = dt_sys.C;

%% Simulacion en Tiempo
T = 200; %Tiempo de simulacion. En Segundos.
dx_lineal = @(t, x) A_matriz*x + B_matriz*[1; -1]; %Aqui se usan variables de desviacion

[t_lin, x_lin] = ode45(dx_lineal, [0, T], zeros(nx, 1));
[t_nolin, x_nolin] = ode45(@quadruple_tank_system, [0, T], ...
    [h1e, h2e, h3e, h4e, u1e+1, u2e-1]);

x_dt = [];
x_dt(:, 1) = zeros(nx, 1);

for k=1:T/Ts
   x_dt(:, k+1) = A_matriz_dt*x_dt(:, k) + B_matriz_dt*[1; -1];
end

figure;
hold on
plot(t_lin, C_matriz*[x_lin' + hequils], 'b', 'LineWidth', 1);
plot(t_nolin, C_matriz*x_nolin(:, 1:4)', 'r', 'LineWidth', 1);
plot(1:Ts:T+1, C_matriz_dt*[x_dt + hequils], 'k--', 'LineWidth', 2);
legend('Lineal 1', 'Lineal 2', 'No Lineal 1', 'No Lineal 2', 'Discreto 1', 'Discreto 2');
xlabel('Tiempo (s)');
ylabel('Altura Tanques (cm)');

%% MPC
clc;
yalmip('clear');
Hp = 50;
Q = 1*diag([1, 1]);
R = diag([1, 1]);

% Constraints
u1_max = 10 - u1e; u1_min = 0 - u1e;
u2_max = 10 - u2e; u2_min = 0 - u2e;
h1_max = 15 - h1e; h1_min = 0 - h1e;
h2_max = 15 - h2e; h2_min = 0 - h2e;
h3_max = 15 - h3e; h3_min = 0 - h3e;
h4_max = 15 - h4e; h4_min = 0 - h4e;

% YALMIP variables
u = sdpvar(nu*ones(1, Hp), ones(1, Hp));
x = sdpvar(nx*ones(1, Hp+1), ones(1, Hp+1));
r = sdpvar(ny, 1);
constraints = [];
objective = 0;

for k=1:Hp
   objective = objective + norm(Q*[r - C_matriz_dt*x{k}], 2).^2 + norm(R*u{k}, 2).^2;
   constraints = [constraints, x{k+1} == A_matriz_dt*x{k} + B_matriz_dt*u{k}]
   constraints = [constraints, u1_min <= u{k}(1) <= u1_max, u2_min <= u{k}(2) <= u2_max];
   constraints = [constraints, h1_min <= x{k+1}(1) <= h1_max, h2_min <= x{k+1}(2) <= h2_max,...
       h3_min <= x{k+1}(3) <= h3_max, h4_min <= x{k+1}(4) <= h4_max];
end

ops = sdpsettings('solver', 'quadprog', 'verbose', 0);
%Instalar el de cplex para la tarea.
%Es gratis con la universidad.

controller = optimizer(constraints, objective, ops, {x{1}, r}, u{1});

x = zeros(nx, 1); 
xs = [x];
us = [zeros(nu, 1)];
ref = C_matriz_dt*[3; 1; 0; 0];

for k=1:100
   k
   uk = controller{x, ref};
   conds = [x(1) + h1e, x(2) + h2e, x(3) + h3e, x(4) + h4e, uk(1) + u1e, uk(2) + u2e];
   [t, x_out] = ode45(@quadruple_tank_system, [0:0.1:Ts], conds);
   
   x = x_out(end, 1:4)' - hequils;
   
   xs = [xs, x];
   us = [us, uk];
end

figure;
hold on
plot(xs(1, :) + h1e, 'r', 'LineWidth', 2);
plot(ones(length(xs))*3+h1e, 'r--', 'LineWidth', 1);
plot(xs(2, :) + h2e, 'b', 'LineWidth', 2);
plot(ones(length(xs))*1+h2e, 'b--', 'LineWidth', 1);
legend('h1', 'Ref h1', 'h2', 'Ref h2');

figure;
hold on
plot(us(1,:) + u1e, 'r', 'LineWidth', 2);
plot(us(2,:) + u2e, 'b', 'LineWidth', 2);
legend('u1', 'u2');


