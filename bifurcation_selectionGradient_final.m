function bifurcation_selectionGradient_demo9()

% Default parameters: N=5, Mc=3, B=4, C=1, K=3

% Panels:
% (a) none: fix C, vary B in [2,5], x-axis shown as B/C
% (b) punishment only: vary S in [0,1]
% (c) reward only: vary R in [0,1]
%
% Styles:
% - Attractor (ESS)                   : solid blue
% - Attractor (branching; not ESS)    : solid green
% - Repeller (unstable)               : dashed red (custom dash/gap)
% Boundary equilibria p=0 and p=1 included.

    % =========================
    % EXPORT SETTINGS (Option B)
    % =========================
    doSave  = true;
    outFile = 'bifurcation.pdf';

    % PNAS widths (typical):
    % single-column ≈ 3.42 in, double-column ≈ 6.9 in
    figW = 6.9;
    figH = 2.2;

    % ---- defaults ----
    par.N  = 5;
    par.Mc = 3;
    par.B  = 4;
    par.C  = 1;
    par.K  = 4;
    par.R  = 0;
    par.S  = 0;

    % ---- sweeps ----
    Bvals = linspace(2, 5, 1001);   % panel (a) computation
    Svals = linspace(0, 1, 1001);   % panel (b)
    Rvals = linspace(0, 1, 1001);   % panel (c)

    % ---- plotting options ----
    opts.branchTol = 0.06;

    % DASH CONTROL (repeller dash segment size)
    opts.dash = 0.020;  % increase => longer dashes
    opts.gap  = 0.010;  % increase => larger gaps

    % Branching criterion sign:
    % branching if opts.branchCurvSign * curvature > 0
    % (standard AD branching: curvature > 0 => set +1)
    opts.branchCurvSign = +1;

    % ---- figure + layout (LOCK SIZE BEFORE tiledlayout) ----
    fig = figure('Color','w');
    set(fig,'Units','inches');
    fig.Position = [1 1 figW figH];     % [left bottom width height]
    set(fig,'InvertHardcopy','off');    % keep background/appearance consistent

    % Use tiledlayout if available; otherwise fallback to subplot.
    useTiled = exist('tiledlayout','file') == 2;

    hasBlueAll  = false;
    hasGreenAll = false;
    hasRedAll   = false;

    if useTiled
        t = tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');
        % Leave headroom for legend. Adjust last number if needed.
        % Smaller height => more room on top.
        try
            t.OuterPosition = [0.05 0.08 0.90 0.72];
        catch
        end

        ax1 = nexttile(t,1);
        ax2 = nexttile(t,2);
        ax3 = nexttile(t,3);
    else
        ax1 = subplot(1,3,1,'Parent',fig);
        ax2 = subplot(1,3,2,'Parent',fig);
        ax3 = subplot(1,3,3,'Parent',fig);
    end

    % ---- panel (a): x = B/C ----
    xA = Bvals / par.C;
    [hb,hg,hr] = plotBifurcation(ax1, 'B', Bvals, xA, 'Benefit-cost ratio, $B/C$', par, "none", opts);
    hasBlueAll  = hasBlueAll  | hb;
    hasGreenAll = hasGreenAll | hg;
    hasRedAll   = hasRedAll   | hr;

    % ---- panel (b): punishment S ----
    [hb,hg,hr] = plotBifurcation(ax2, 'S', Svals, Svals, 'Punishment, $S$', par, "punishment", opts);
    hasBlueAll  = hasBlueAll  | hb;
    hasGreenAll = hasGreenAll | hg;
    hasRedAll   = hasRedAll   | hr;

    % ---- panel (c): reward R ----
    [hb,hg,hr] = plotBifurcation(ax3, 'R', Rvals, Rvals, 'Reward, $R$', par, "reward", opts);
    hasBlueAll  = hasBlueAll  | hb;
    hasGreenAll = hasGreenAll | hg;
    hasRedAll   = hasRedAll   | hr;

    % ---- unified legend on top (VERSION-ROBUST) ----
    axL = axes('Parent', fig, 'Position',[0 0 1 1], 'Visible','off', 'HitTest','off');
    hold(axL,'on');

    hL = gobjects(0); labelsL = {};

    if hasBlueAll
        hL(end+1) = plot(axL, nan, nan, 'b-', 'LineWidth', 2); %#ok<AGROW>
        labelsL{end+1} = 'Attractor (ESS)'; %#ok<AGROW>
    end
    if hasGreenAll
        hL(end+1) = plot(axL, nan, nan, 'g-', 'LineWidth', 2); %#ok<AGROW>
        labelsL{end+1} = 'Attractor (branching; not ESS)'; %#ok<AGROW>
    end
    if hasRedAll
        hL(end+1) = plot(axL, nan, nan, 'r--', 'LineWidth', 2); %#ok<AGROW>
        labelsL{end+1} = 'Repeller (unstable)'; %#ok<AGROW>
    end

    if ~isempty(hL)
        lg = legend(axL, hL, labelsL, ...
            'Orientation','horizontal', ...
            'Interpreter','latex', ...
            'Box','off');

        lg.Units = 'normalized';
        legendW = 0.90;
        legendH = 0.045;
        legendX = (1 - legendW)/2;
        legendY = 0.955;
        lg.Position = [legendX legendY legendW legendH];
    end

    % =========================
    % FINALIZE + EXPORT (Option B)
    % =========================
    drawnow; % ensures tiledlayout + legend positions are finalized

    if doSave
        % Match PDF page exactly to figure size
        set(fig,'PaperUnits','inches');
        set(fig,'PaperSize', fig.Position(3:4));               % [W H]
        set(fig,'PaperPosition', [0 0 fig.Position(3:4)]);     % no margins
        set(fig,'PaperPositionMode','manual');

        % Vector PDF export
        set(fig,'Renderer','painters');
        print(fig, outFile, '-dpdf', '-painters');
        fprintf('Saved PDF: %s (%.2f x %.2f in)\n', outFile, fig.Position(3), fig.Position(4));
    end
end


function [hasBlue, hasGreen, hasRed] = plotBifurcation(ax, paramName, paramVals, xPlotVals, xLabelLatex, parBase, mode, opts)
% Plot bifurcation branches on given axes; return which types appear.

    n = numel(paramVals);

    stableESSRoots    = cell(n,1);
    stableBranchRoots = cell(n,1);
    unstableRoots     = cell(n,1);

    for i = 1:n
        par = parBase;
        par.(paramName) = paramVals(i);

        switch mode
            case "none"
                par.R = 0; par.S = 0;
            case "reward"
                par.S = 0;
            case "punishment"
                par.R = 0;
        end

        roots = findEquilibriaInterior(par);
        [stESS, stBr, un] = classifyStabilityAndBranching(roots, par, opts);
        [stB, unB] = classifyBoundaries(par);

        stableESSRoots{i}    = sort([stESS(:); stB(:)]);
        stableBranchRoots{i} = sort(stBr(:));
        unstableRoots{i}     = sort([un(:); unB(:)]);
    end

    stableESSMat    = trackBranches(stableESSRoots,    opts.branchTol);
    stableBranchMat = trackBranches(stableBranchRoots, opts.branchTol);
    unstableMat     = trackBranches(unstableRoots,     opts.branchTol);

    cla(ax);
    hold(ax,'on');

    hasBlue  = any(isfinite(stableESSMat(:)));
    hasGreen = any(isfinite(stableBranchMat(:)));
    hasRed   = any(isfinite(unstableMat(:)));

    if hasBlue
        for b = 1:size(stableESSMat,1)
            plot(ax, xPlotVals, stableESSMat(b,:), 'b-', 'LineWidth', 2);
        end
    end

    if hasGreen
        for b = 1:size(stableBranchMat,1)
            plot(ax, xPlotVals, stableBranchMat(b,:), 'g-', 'LineWidth', 2);
        end
    end

    if hasRed
        for b = 1:size(unstableMat,1)
            x = xPlotVals(:);
            y = unstableMat(b,:).';
            [xd, yd] = makeDashedXY(ax, x, y, opts.dash, opts.gap);
            plot(ax, xd, yd, 'r-', 'LineWidth', 2);
        end
    end

    ylim(ax,[0 1]);
    xlim(ax,[xPlotVals(1) xPlotVals(end)]);
    grid(ax,'on');

    xlabel(ax, xLabelLatex, 'Interpreter','latex');
    ylabel(ax, 'Probability to cooperate, $p^*$', 'Interpreter','latex');
end


function g = selectionGradient(p, par)
% Base: g0(p) = -C + B * BinomialPMF(Mc-1; N-1, p)
% Reward: + R*K*p^(K-1)
% Punish: + S*K*(1-p)^(K-1)

    N  = par.N;
    Mc = par.Mc;

    B = par.B;
    C = par.C;
    K = par.K;

    if ~isfield(par,'R'), par.R = 0; end
    if ~isfield(par,'S'), par.S = 0; end

    coeff = nchoosek(N-1, Mc-1);
    g0 = -C + B * coeff .* (p.^(Mc-1)) .* ((1-p).^(N-Mc));

    rewardTerm     = par.R * K .* (p.^(K-1));
    punishmentTerm = par.S * K .* ((1-p).^(K-1));

    g = g0 + rewardTerm + punishmentTerm;
end


function roots = findEquilibriaInterior(par)
    pGrid = linspace(0, 1, 5001);
    gGrid = selectionGradient(pGrid, par);

    roots = [];

    % sign-change bracketing
    for j = 1:numel(pGrid)-1
        gj  = gGrid(j);
        gj1 = gGrid(j+1);

        if gj == 0
            roots(end+1) = pGrid(j); %#ok<AGROW>
        elseif gj * gj1 < 0
            a = pGrid(j); b = pGrid(j+1);
            try
                roots(end+1) = fzero(@(x) selectionGradient(x, par), [a b]); %#ok<AGROW>
            catch
            end
        end
    end

    % tangency safety (near-zero local minima of |g|)
    absG = abs(gGrid);
    idx = find( absG(2:end-1) <= absG(1:end-2) & absG(2:end-1) <= absG(3:end) ...
                & absG(2:end-1) < 1e-4 ) + 1;
    for k = 1:numel(idx)
        j = idx(k);
        a = pGrid(max(1,j-1));
        b = pGrid(min(numel(pGrid),j+1));
        try
            roots(end+1) = fzero(@(x) selectionGradient(x, par), [a b]); %#ok<AGROW>
        catch
            if abs(selectionGradient(pGrid(j), par)) < 1e-5
                roots(end+1) = pGrid(j); %#ok<AGROW>
            end
        end
    end

    roots = roots(roots > 1e-8 & roots < 1-1e-8);
    roots = dedup(roots, 1e-4);
end


function [stableESS, stableBranch, unstable] = classifyStabilityAndBranching(roots, par, opts)
    stableESS = [];
    stableBranch = [];
    unstable = [];

    h = 1e-6;
    K = par.K;

    for i = 1:numel(roots)
        p = roots(i);

        gp = (selectionGradient(min(1,p+h), par) - selectionGradient(max(0,p-h), par)) / (2*h);

        % curvature contributed by mutant-payoff add-ons at x=p
        curv = 0;
        if isfield(par,'R') && par.R ~= 0
            curv = curv + par.R * K * (K-1) * (p^(K-2));
        end
        if isfield(par,'S') && par.S ~= 0
            curv = curv - par.S * K * (K-1) * ((1-p)^(K-2));
        end

        if gp < 0
            if opts.branchCurvSign * curv > 0
                stableBranch(end+1) = p; %#ok<AGROW>
            else
                stableESS(end+1) = p; %#ok<AGROW>
            end
        else
            unstable(end+1) = p; %#ok<AGROW>
        end
    end
end


function [stableB, unstableB] = classifyBoundaries(par)
    eps = 1e-6;
    stableB = [];
    unstableB = [];

    g0 = selectionGradient(eps, par);
    if g0 < 0, stableB(end+1)=0; else, unstableB(end+1)=0; end %#ok<AGROW>

    g1 = selectionGradient(1-eps, par);
    if g1 > 0, stableB(end+1)=1; else, unstableB(end+1)=1; end %#ok<AGROW>
end


function [xd, yd] = makeDashedXY(ax, x, y, dashLen, gapLen)
% Break a polyline into dashed segments by inserting NaNs.
% dashLen/gapLen are in axis-normalized arc-length units.

    valid = ~(isnan(x) | isnan(y));
    xd = nan(size(x));
    yd = nan(size(y));
    if nnz(valid) < 2, return; end

    xl = xlim(ax); yl = ylim(ax);
    xn = (x - xl(1)) ./ max(eps, diff(xl));
    yn = (y - yl(1)) ./ max(eps, diff(yl));

    idx = find(valid);
    runs = splitIntoRuns(idx);

    period = dashLen + gapLen;

    for r = 1:size(runs,1)
        a = runs(r,1); b = runs(r,2);
        xs = x(a:b); ys = y(a:b);
        xns = xn(a:b); yns = yn(a:b);

        s = [0; cumsum(hypot(diff(xns), diff(yns)))];
        on = mod(s, period) < dashLen;

        xs(~on) = nan;
        ys(~on) = nan;

        xd(a:b) = xs;
        yd(a:b) = ys;
    end
end


function runs = splitIntoRuns(idxs)
    if isempty(idxs), runs = zeros(0,2); return; end
    d = diff(idxs);
    breaks = [0; find(d>1); numel(idxs)];
    runs = zeros(numel(breaks)-1,2);
    for k = 1:numel(breaks)-1
        s = breaks(k)+1;
        t = breaks(k+1);
        runs(k,:) = [idxs(s), idxs(t)];
    end
end


function branchMat = trackBranches(rootCells, tol)
    n = numel(rootCells);
    branches = {};

    for i = 1:n
        r = rootCells{i}(:)';
        used = false(size(r));

        if i == 1
            for j = 1:numel(r)
                v = nan(1,n);
                v(i) = r(j);
                branches{end+1} = v; %#ok<AGROW>
                used(j) = true;
            end
        else
            for b = 1:numel(branches)
                prevIdx = find(~isnan(branches{b}(1:i-1)), 1, 'last');
                if isempty(prevIdx), continue; end
                prevVal = branches{b}(prevIdx);

                if isempty(r)
                    branches{b}(i) = nan;
                    continue;
                end

                [dmin, jmin] = min(abs(r - prevVal));
                if dmin < tol && ~used(jmin)
                    branches{b}(i) = r(jmin);
                    used(jmin) = true;
                else
                    branches{b}(i) = nan;
                end
            end

            for j = find(~used)
                v = nan(1,n);
                v(i) = r(j);
                branches{end+1} = v; %#ok<AGROW>
            end
        end
    end

    branchMat = nan(numel(branches), n);
    for b = 1:numel(branches)
        branchMat(b,:) = branches{b};
    end
end


function x = dedup(x, tol)
    if isempty(x), return; end
    x = sort(x(:));
    keep = true(size(x));
    for i = 2:numel(x)
        if abs(x(i) - x(i-1)) < tol
            keep(i) = false;
        end
    end
    x = x(keep);
end