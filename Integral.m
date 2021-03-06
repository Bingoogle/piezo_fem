classdef Integral
    % Integral Class
    % Works as a library not as a data structure.
    % Main methods:
    %   - Surface2D
    %   - Volume3D
    methods (Static)
        function mat_out = Surface2D(fun_in,order,a,b)
            % mat_out = Surface2D(fun_in,order,interval)
            % mat_out [fun_size,fun_size]
            % fun_in [Fhandle] function(ksi,eta) to be integrated
            % order [Int]: Gauss integration
            % [a,b] => interval [1x2][Float]: Surface sides for integration
            [g_p,g_w] = Integral.lgwt(order,a,b);
            points  = {g_p,g_p};
            weights = {g_w,g_w};
            mat_out = Integral.quadrature(points,weights,fun_in);
        end
        function mat_out = Volume3D(fun_in,order,a,b)
            % mat_out = Volume3D(fun_in,fun_size,order,interval)
            % mat_out [fun_size,fun_size]
            % fun_in [Fhandle] function(xi,eta,mu) to be integrated
            % order [Int][>0] Gauss integration
            % [a,b] => interval [1x2][Float]:  Cube sides for integration
            % sampling points & weights
            [g_p,g_w] = Integral.lgwt(order,a,b);
            points  = {g_p, g_p, g_p};
            weights = {g_w, g_w, g_w};
            mat_out = Integral.quadrature(points,weights,fun_in);
        end
        function mat_out = quadrature(points,weights,fun_in)
            % mat_out = generic_quadrature(points,weigths,fun_in)
            % mat_out [fun_in output size]
            % fun_in [Fhandle] function(xi,eta,mu) to be integrated
            % points {[n_points x 1] x dim}: Places where the function should be
            % evaluated
            % weights {[n_points x 1] x dim}: Weights to assign to each of those
            % evaluations
            require(all(size(points) == size(weights)), ...
                'ArgumentError: points and weights should have same size');
            require(nargin(fun_in) == size(points,2), ...
                'ArgumentError: points columns should == fun_in number of args');
            %% Prepare values for variable length argument lists
            % allcomb() should take a variable argument list and that can
            % only be done by having points and weights as cells
            dim   = size(points,2);  % Dimensions
            try_values  = cell(1,dim);
            for d = 1:dim
                try_values{d} = points{d}(1);
            end
            %% Get all possible combinations of the points and weights
            % By having all the combinations in an explicit array form
            % where each row is a combination, the summation can be done
            % with only one loop.
            p_comb  = Integral.allcomb(points{:});
            w_comb  = Integral.allcomb(weights{:});
            %% Integrate along those combinations
            % Initialization of Matrix
            mat_out = zeros(size(fun_in(try_values{:})));
            for i = 1:size(p_comb,1)
                var_args = cell(1,dim);
                for d = 1:dim
                    var_args{d} = p_comb(i,d);
                end
                mat_out = mat_out + prod(w_comb(i,:))*fun_in(var_args{:});
            end
        end
        %% 1D Gauss Functions
        function [x,w] = lgwt(N,a,b)
            % lgwt.m
            %
            % This script is for computing definite integrals using Legendre-Gauss
            % Quadrature. Computes the Legendre-Gauss nodes and weights  on an interval
            % [a,b] with truncation order N
            %
            % Suppose you have a continuous function f(x) which is defined on [a,b]
            % which you can evaluate at any x in [a,b]. Simply evaluate it at all of
            % the values contained in the x vector to obtain a vector f. Then compute
            % the definite integral using sum(f.*w);
            %
            % Written by Greg von Winckel - 02/25/2004
            require(isnumeric(N), ...
                'ArgumentError: order should be numeric');
            require(N > 0, ...
                'ArgumentError: order should be > 0');
            require(~mod(N,1), ...
                'ArgumentError: order should be integer');
            require(isnumeric([a b]), ...
                'ArgumentError: interval [a b] should be numeric');
            N=N-1;
            N1=N+1; N2=N+2;
            xu=linspace(-1,1,N1)';
            % Initial guess
            y=cos((2*(0:N)'+1)*pi/(2*N+2))+(0.27/N1)*sin(pi*xu*N/N2);
            % Legendre-Gauss Vandermonde Matrix
            L=zeros(N1,N2);
            % Derivative of LGVM
            Lp=zeros(N1,N2);
            % Compute the zeros of the N+1 Legendre Polynomial
            % using the recursion relation and the Newton-Raphson method
            y0=2;
            % Iterate until new points are uniformly within epsilon of old points
            while max(abs(y-y0))>eps
                L(:,1)=1;
                Lp(:,1)=0;
                L(:,2)=y;
                Lp(:,2)=1;
                for k=2:N1
                    L(:,k+1)=( (2*k-1)*y.*L(:,k)-(k-1)*L(:,k-1) )/k;
                end
                Lp=(N2)*( L(:,N1)-y.*L(:,N2) )./(1-y.^2);
                y0=y;
                y=y0-L(:,N2)./Lp;
                
            end
            % Linear map from[-1,1] to [a,b]
            x=(a*(1-y)+b*(1+y))/2;
            % Compute the weights
            w=(b-a)./((1-y.^2).*Lp.^2)*(N2/N1)^2;
        end
        function [w, gp, n] = gauss(ng)
            % [w, gp, n] = gauss(ng)
            % ng: [Int][dim x 1] where each component indicates how many gauss points
            % shold be used to integrate along that direction
            % wgauss [n x 1]:     Gauss weights
            % gpts [n x dim]:     Evaluation points for each coordinates
            % n [Int]:            Number of evaluation points
            % The function works by calling Integral.gauss1D for each dimension and then
            % assembling w and gp.
            % Note: n is redundant as an output since it is contained in length(wgauss)
            dims = length(ng);
            n = prod(ng);
            w = ones(n,1);
            gp = zeros(n,dims);
            switch dims
                case 3
                    [w1,gp1] = Integral.gauss1D(ng(1));
                    [w2,gp2] = Integral.gauss1D(ng(2));
                    [w3,gp3] = Integral.gauss1D(ng(3));
                    
                    counter = 1;
                    for ig1 = 1:ng(1)
                        for ig2 = 1:ng(2)
                            for ig3 = 1:ng(3)
                                w(counter) = w(counter)*w1(ig1)*w2(ig2)*w3(ig3);
                                gp(counter,:) = [gp1(ig1) gp2(ig2) gp3(ig3)];
                                counter = counter + 1;
                            end
                        end
                    end
                case 2
                    [w1,gp1] = Integral.gauss1D(ng(1));
                    [w2,gp2] = Integral.gauss1D(ng(2));
                    
                    counter = 1;
                    for ig1 = 1:ng(1)
                        for ig2 = 1:ng(2)
                            w(counter) = w(counter)*w1(ig1)*w2(ig2);
                            gp(counter,:) = [gp1(ig1) gp2(ig2)];
                            counter = counter + 1;
                        end
                    end
                case 1
                    [w,gp] = Integral.gauss1D(n);
                    w = w';
                    gp = gp';
            end
        end
        function [w,gp] = gauss1D(n)
            % [w,gp] = Integral.gauss1D(n)
            % n [Int]: number of points along the line
            % w [Float][n x 1]:     Gauss weights for integration along the line
            % gp [Float][n x 1]:    Places where to evaluate the function
            
            % When approximating integral(f(x),x_0,x_1) with sum(w*f(gp(i))) this
            % function returns the values where to evaluate the function (gp) and the
            % weight that should be assigned to each result (w)
            switch n
                case 1
                    w  = 2;
                    gp = 0;
                case 2
                    w  = [1 1];
                    a  = sqrt(3)/3;
                    gp = [-a a];
                case 3
                    w  = [5/9 8/9 5/9];
                    a  = sqrt(3/5);
                    gp = [-a 0 a];
                case 4
                    a  = sqrt((3 - 2*sqrt(6/5))/7);
                    b  = sqrt((3 + 2*sqrt(6/5))/7);
                    gp = [-b -a a b];
                    wa = (18 + sqrt(30))/36;
                    wb = (18 - sqrt(30))/36;
                    w  = [wb wa wa wb];
                case 5
                    a  = 1/3*sqrt(5 - 2*sqrt(10/7));
                    b  = 1/3*sqrt(5 + 2*sqrt(10/7));
                    gp = [-b -a 0 a b];
                    wa = (322 + 13*sqrt(70))/900;
                    wb = (322 - 13*sqrt(70))/900;
                    w  = [wb wa 128/225 wa wb];
                case 6
                    a  = 0.932469514203152;
                    b  = 0.661209386466265;
                    c  = 0.238619186083197;
                    wa = 0.171324492379170;
                    wb = 0.360761573048139;
                    wc = 0.467913934572691;
                    gp = [-a -b -c c b a];
                    w  = [wa wb wc wc wb wa];
                    %     case 7
                    %         a  = 0.949107912342759;
                    %         b  = 0.741531185599394;
                    %         c  = 0.405845151377397;
                    %         d  = 0.0;
                    %         wa = 0.129484966168870;
                    %         wb = 0.279705391489277;
                    %         wc = 0.381830050505119;
                    %         wd = 0.417959183673469;
                    %         gp = [-a -b -c d c b a];
                    %         w  = [wa wb wc wd wc wb wa];
                    %     case 8
                    %         a  = 0.932469514203152;
                    %         b  = 0.661209386466265;
                    %         c  = 0.238619186083197;
                    %         wa = 0.171324492379170;
                    %         wb = 0.360761573048139;
                    %         wc = 0.467913934572691;
                    %         gp = [-a -b -c c b a];
                    %         w  = [wa wb wc wc wb wa];
                    %     case 9
                    %         a  = 0.932469514203152;
                    %         b  = 0.661209386466265;
                    %         c  = 0.238619186083197;
                    %         wa = 0.171324492379170;
                    %         wb = 0.360761573048139;
                    %         wc = 0.467913934572691;
                    %         gp = [-a -b -c c b a];
                    %         w  = [wa wb wc wc wb wa];
                    %     case 10
                    %         a  = 0.932469514203152;
                    %         b  = 0.661209386466265;
                    %         c  = 0.238619186083197;
                    %         wa = 0.171324492379170;
                    %         wb = 0.360761573048139;
                    %         wc = 0.467913934572691;
                    %         gp = [-a -b -c c b a];
                    %         w  = [wa wb wc wc wb wa];
            end
        end
        %% Helper methods
        function A = allcomb(varargin)
            % ALLCOMB - All combinations
            %    B = ALLCOMB(A1,A2,A3,...,AN) returns all combinations of the elements
            %    in the arrays A1, A2, ..., and AN. B is P-by-N matrix is which P is the product
            %    of the number of elements of the N inputs. This functionality is also
            %    known as the Cartesian Product. The arguments can be numerical and/or
            %    characters, or they can be cell arrays.
            %
            %    Examples:
            %       allcomb([1 3 5],[-3 8],[0 1]) % numerical input:
            %       % -> [ 1  -3   0
            %       %      1  -3   1
            %       %      1   8   0
            %       %        ...
            %       %      5  -3   1
            %       %      5   8   1 ] ; % a 12-by-3 array
            %
            %       allcomb('abc','XY') % character arrays
            %       % -> [ aX ; aY ; bX ; bY ; cX ; cY] % a 6-by-2 character array
            %
            %       allcomb('xy',[65 66]) % a combination
            %       % -> ['xA' ; 'xB' ; 'yA' ; 'yB'] % a 4-by-2 character array
            %
            %       allcomb({'hello','Bye'},{'Joe', 10:12},{99999 []}) % all cell arrays
            %       % -> {  'hello'  'Joe'        [99999]
            %       %       'hello'  'Joe'             []
            %       %       'hello'  [1x3 double] [99999]
            %       %       'hello'  [1x3 double]      []
            %       %       'Bye'    'Joe'        [99999]
            %       %       'Bye'    'Joe'             []
            %       %       'Bye'    [1x3 double] [99999]
            %       %       'Bye'    [1x3 double]      [] } ; % a 8-by-3 cell array
            %
            %    ALLCOMB(..., 'matlab') causes the first column to change fastest which
            %    is consistent with matlab indexing. Example:
            %      allcomb(1:2,3:4,5:6,'matlab')
            %      % -> [ 1 3 5 ; 1 4 5 ; 1 3 6 ; ... ; 2 4 6 ]
            %
            %    If one of the arguments is empty, ALLCOMB returns a 0-by-N empty array.
            %
            %    See also NCHOOSEK, PERMS, NDGRID
            %         and NCHOOSE, COMBN, KTHCOMBN (Matlab Central FEX)
            % for Matlab R2011b
            % version 4.0 (feb 2014)
            % (c) Jos van der Geest
            % email: jos@jasen.nl
            error(nargchk(1,Inf,nargin)) ;
            NC = nargin ;
            % check if we should flip the order
            if ischar(varargin{end}) && (strcmpi(varargin{end},'matlab') || strcmpi(varargin{end},'john')),
                % based on a suggestion by JD on the FEX
                NC = NC-1;
                ii = 1:NC; % now first argument will change fastest
            else
                % default: enter arguments backwards, so last one (AN) is changing fastest
                ii = NC:-1:1 ;
            end
            % check for empty inputs
            if any(cellfun('isempty',varargin(ii))),
                warning('ALLCOMB:EmptyInput','Empty inputs result in an empty output.') ;
                A = zeros(0,NC) ;
            elseif NC > 1
                isCellInput = cellfun(@iscell,varargin);
                if any(isCellInput)
                    if ~all(isCellInput)
                        error('ALLCOMB:InvalidCellInput', ...
                            'For cell input, all arguments should be cell arrays.') ;
                    end
                    % for cell input, we use to indices to get all combinations
                    ix = cellfun(@(c) 1:numel(c), varargin,'un',0);
                    % flip using ii if last column is changing fastest
                    [ix{ii}] = ndgrid(ix{ii}) ;
                    A = cell(numel(ix{1}),NC) ; % pre-allocate the output
                    for k=1:NC,
                        % combine
                        A(:,k) = reshape(varargin{k}(ix{k}),[],1);
                    end
                else
                    % non-cell input, assuming all numerical values or strings
                    % flip using ii if last column is changing fastest
                    [A{ii}] = ndgrid(varargin{ii});
                    % concatenate
                    A = reshape(cat(NC+1,A{:}),[],NC);
                end
            elseif NC==1,
                A = varargin{1}(:); % nothing to combine
            else % NC==0, there was only the 'matlab' flag argument
                A = zeros(0,0); % nothing
            end
        end
    end
end