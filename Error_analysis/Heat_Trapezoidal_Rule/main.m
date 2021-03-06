function error = main(Ntr,dt,T)
clc; close all

addpath ./Kernels
addpath ./Utilities

rng('default')

global ModelInfo

set(0,'defaulttextinterpreter','latex')

%% Setup
N_D = 10;
Ntr_artificial = Ntr;
dim = 2;
lb = zeros(1,dim);
ub = 1.0*ones(1,dim);
jitter = 1e-8;
ModelInfo.jitter=jitter;
noise = 0.0;

plt = 0;

ModelInfo.dt = dt;

nsteps = T/dt;

nn = 25;
xx1 = linspace(0, 1, nn)';
xx2 = linspace(0, 1, nn)';
[Xplot, Yplot] = meshgrid(xx1,xx2);
xstar = reshape([Xplot Yplot], nn^2, 2);
u_star = Exact_solution(0,xstar);
u_star_plot = griddata(xstar(:,1),xstar(:,2),u_star,Xplot,Yplot,'cubic');

num_plots = 2;

%% Optimize model

x_D_1 = [zeros(N_D,1) bsxfun(@plus,lb(2),bsxfun(@times,   lhsdesign(N_D,1)    ,(ub(2)-lb(2))))];
x_D_2 = [ones(N_D,1) bsxfun(@plus,lb(2),bsxfun(@times,   lhsdesign(N_D,1)    ,(ub(2)-lb(2))))];
x_D_3 = [bsxfun(@plus,lb(1),bsxfun(@times,   lhsdesign(N_D,1)    ,(ub(1)-lb(1)))) zeros(N_D,1)];

ModelInfo.x_D = [x_D_1;x_D_2;x_D_3];
ModelInfo.u_D = Exact_solution(0, ModelInfo.x_D);

ModelInfo.x_N = [bsxfun(@plus,lb(1),bsxfun(@times,   lhsdesign(N_D,1)    ,(ub(1)-lb(1)))) ones(N_D,1)];
ModelInfo.v_N = Exact_solution_x2(0, ModelInfo.x_N);

ModelInfo.x_u = bsxfun(@plus,lb,bsxfun(@times,   lhsdesign(Ntr,dim)    ,(ub-lb)));
ModelInfo.u = Exact_solution(0, ModelInfo.x_u);
ModelInfo.u = ModelInfo.u + noise*randn(size(ModelInfo.u));

ModelInfo.S0 = zeros(Ntr);

ModelInfo.hyp = log([1 1 1 1 1 1 exp(-6)]);

if plt == 1
    fig = figure(1);
    set(fig,'units','normalized','outerposition',[0 0 1 .5])
    %set(fig,'units','normalized','outerposition',[0 0 1 1])
    clf
    k = 1;
    subplot(2,num_plots,k)
    hold
    
    az = -120;
    el = 25;
    view(az, el);
    axis tight
    s1 = surf(Xplot,Yplot,u_star_plot);
    set(s1,'FaceLighting','flat','FaceColor','b','EdgeColor','b', 'LineStyle','-','LineWidth',1,'FaceAlpha',0.25);
    plot3(ModelInfo.x_u(:,1), ModelInfo.x_u(:,2), ModelInfo.u,'ro', 'MarkerEdgeColor','r','MarkerSize',12,'LineWidth',3);
    ylabel('$x_2$')
    xlabel('$x_1$')
    zlabel('$u(0,x_1,x_2)$')
    set(gca,'FontSize',14);
    set(gcf, 'Color', 'w');
    tit = sprintf('Time: %.2f\n%d training points', 0,Ntr);
    title(tit);
    
    drawnow;
end

%%
for i = 1:nsteps
    
    [ModelInfo.hyp,~,~] = minimize(ModelInfo.hyp, @likelihood, -5000);
    [NLML,~]=likelihood(ModelInfo.hyp);
    
    [Kpred, Kvar] = predictor(xstar);
    Kvar = abs(diag(Kvar));
    Kpred_upper_bound = Kpred + 2*sqrt(Kvar);
    Kpred_lower_bound = Kpred - 2*sqrt(Kvar);
    Exact = Exact_solution( i*dt, xstar);
    error = norm(Kpred-Exact,2)/norm(Exact,2);
    
    fprintf(1,'Step: %d, Time = %f, NLML = %e, error_u = %e\n', i, i*dt, NLML, error);
    
    x_u = bsxfun(@plus,lb,bsxfun(@times,   lhsdesign(Ntr_artificial,dim)    ,(ub-lb)));
    [ModelInfo.u, ModelInfo.S0] = predictor(x_u);
    ModelInfo.x_u = x_u;
    
    if plt == 1 && mod(i,floor(nsteps/(2*num_plots-1)))==0
        k = k+1;
        subplot(2,num_plots,k)
        hold
        Kpred_plot = griddata(xstar(:,1),xstar(:,2),Kpred,Xplot,Yplot,'cubic');
        Kpred_upper_bound_plot = griddata(xstar(:,1),xstar(:,2),Kpred_upper_bound,Xplot,Yplot,'cubic');
        Kpred_lower_bound_plot = griddata(xstar(:,1),xstar(:,2),Kpred_lower_bound,Xplot,Yplot,'cubic');
        Exact_plot = griddata(xstar(:,1),xstar(:,2),Exact,Xplot,Yplot,'cubic');
        
        az = -120;
        el = 25;
        view(az, el);
        axis tight
        s1 = surf(Xplot,Yplot,Kpred_plot);
        set(s1,'FaceLighting','flat', 'FaceColor','r','EdgeColor','r', 'LineStyle','--','LineWidth',1,'FaceAlpha',0.5);
        s2 = surf(Xplot,Yplot,Exact_plot);
        set(s2,'FaceLighting','flat','FaceColor','b','EdgeColor','b', 'LineStyle','-','LineWidth',1,'FaceAlpha',0.25);
        s3 = surf(Xplot,Yplot,Kpred_upper_bound_plot);
        set(s3,'FaceLighting','flat','FaceColor','k','EdgeColor','k', 'LineStyle',':','LineWidth',1.5,'FaceAlpha',0);
        s4 = surf(Xplot,Yplot,Kpred_lower_bound_plot);
        set(s4,'FaceLighting','flat','FaceColor','k','EdgeColor','k', 'LineStyle',':','LineWidth',1.5,'FaceAlpha',0);
        ylabel('$x_2$')
        xlabel('$x_1$')
        zlabel('$u(t,x_1,x_2)$')
        set(gca,'FontSize',14);
        set(gcf, 'Color', 'w');
        tit = sprintf('Time: %.2f\n%d artificial data', i*dt , Ntr_artificial);
        title(tit);
        
        drawnow;
    end
    
    
end

rmpath ./Kernels
rmpath ./Utilities