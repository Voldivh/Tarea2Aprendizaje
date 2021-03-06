clc;

Tsim = 1e-3;
tspan = 0:Tsim:15;

%tspan = [0 5];

p0 = [0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0];
tao = [0; 0; 0; 0; 0; 0];

[t, p] = ode45(@(t,y) auv_system(t,y,tao), tspan, p0);

disp("Terminado.");

%% Graficas

titulos = ["Posiciones", "Angulos", "Velocidades Lineales", "Velocidades Angulares"];
ylabels = ["Posici�n (m)", "�ngulo (rad)", "Velocidad (m/s)", "Velocidad Angular (rad/s)"];

figure;

for j=1:4
    subplot(2,2,j);
    hold on

    for i=1+(j-1)*3:3*j
       plot(t, p(:, i));
    end
    legend('x', 'y', 'z');
    title(titulos(j));
    xlabel("Tiempo (s)")
    ylabel(ylabels(j));
    
    grid on
end

figure;
hold on

plot3(p(:,1), p(:,2), p(:,3), 'LineWidth', 1);
title('Posici�n en X, Y, Z');
xlabel('x');
ylabel('y');
zlabel('z');

grid on

dir = diff([p(:,1), p(:,2), p(:,3)]);
dir = [zeros(1,3); dir];
q = quiver3(p(:,1), p(:,2), p(:,3), dir(:,1), dir(:,2), dir(:,3) , 'LineWidth', 2);
q.MaxHeadSize = 0.5;
q.LineWidth = 0.1;
q.AutoScale = 'off';

grid on