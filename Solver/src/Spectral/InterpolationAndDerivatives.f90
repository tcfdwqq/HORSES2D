!
!///////////////////////////////////////////////////////////////////////////////////////////////////////
!
!    HORSES2D - A high-order discontinuous Galerkin spectral element solver.
!    Copyright (C) 2009  David A. Kopriva 
!
!    This program is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    This program is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
!////////////////////////////////////////////////////////////////////////////////////////////////////////
!

!////////////////////////////////////////////////////////////////////////
!
!      Interpolation.F95
!      Created: 2009-12-15 15:36:24 -0500 
!      By: David Kopriva  
!
!
!      Contains:
!               
!               SUBROUTINE InterpolatingPolynomialVector( x, N, nodes, weights, p )
!               REAL(KIND=RP) FUNCTION EvaluateLagrangePolyDerivative( j, x, N, nodes)
!
!               ALGORITHM 30: SUBROUTINE BarycentricWeights( N, x, w )
!               ALGORITHM 31: REAL(KIND=RP) FUNCTION LagrangeInterpolation( x, N, nodes, values, weights)
!               ALGORITHM 32: SUBROUTINE PolynomialInterpolationMatrix( N, M, oldNodes, weights, newNodes, T)
!               ALGORITHM 33: SUBROUTINE InterpolateToNewPoints( N, M, T, f, fInterp )
!               ALGORITHM 34: REAL(KIND=RP) FUNCTION LagrangeInterpolatingPolynomial( j, x, N, nodes )
!               ALGORITHM 35: 
!               ALGORITHM 36: REAL(KIND=RP) FUNCTION LagrangeInterpolantDerivative( x, N, nodes, values, weights)
!               ALGORITHM 37: SUBROUTINE PolynomialDerivativeMatrix( N, nodes, D )
!               ALGORITHM 38: SUBROUTINE mthPolynomialDerivativeMatrix( m, N, nodes, D )
!               ALGORITHM 39: SUBROUTINE EOMatrixDerivative( u, uDeriv, D, N )
!
!               The following are combined:
!                  ALGORITHM 19: MXVDerivative
!                  ALGORITHM 106: TransposeMatrixMultiply
!               as SUBROUTINE MatrixMultiplyDeriv( f, fDeriv, D, N, transp )
!
!      
!////////////////////////////////////////////////////////////////////////
!
!
!  ******
   MODULE InterpolationAndDerivatives
!  ******
!
     USE SMConstants
     IMPLICIT NONE
     
     INTEGER, PARAMETER :: MXV_DIRECT = 1, MXV_TRANSPOSE = 2
!
!    ========
     CONTAINS
!    ========
!
!    /////////////////////////////////////////////////////////////////
!
      REAL(KIND=RP) FUNCTION LagrangeInterpolatingPolynomialDirect( j, x, N, nodes ) RESULT(p)
!
!---------------------------------------------------------------------
! Compute L_j(x), j=0,...,N of degree N whose zeros are at the nodes using direct
! evaluation.
!---------------------------------------------------------------------
!
      INTEGER                      , INTENT(IN) :: j     !! Which polynomial
      INTEGER                      , INTENT(IN) :: N     !! Polynomial order
      REAL(KIND=RP)                , INTENT(IN) :: x     !! evaluation point
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN) :: nodes !! Interpolation nodes  
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER :: k
      
      IF ( j == 0 )     THEN
         p = (x - nodes(1))/(nodes(j) - nodes(1))
         DO k = 2, N 
            p = p*(x - nodes(k))/(nodes(j) - nodes(k))
         END DO
      ELSE
         p = (x - nodes(0))/(nodes(j) - nodes(0))
         DO k = 1, j-1 
            p = p*(x - nodes(k))/(nodes(j) - nodes(k))
         END DO
         DO k = j+1, N
            p = p*(x - nodes(k))/(nodes(j) - nodes(k))
         END DO
      END IF
   END FUNCTION LagrangeInterpolatingPolynomialDirect
!
!    /////////////////////////////////////////////////////////////////
!
      pure SUBROUTINE LagrangeInterpolatingPolynomialBarycentric( x, N, nodes, weights, p )
      use Utilities
!
!---------------------------------------------------------------------
! Compute L_j(x), j = 0, ..., N of degree N whose zeros are at the nodes 
! using barycentric form.
!---------------------------------------------------------------------
!
      INTEGER                      , INTENT(IN)  :: N       !! Polynomial order
      REAL(KIND=RP)                , INTENT(IN)  :: x       !! evaluation point
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN)  :: nodes   !! Interpolation nodes
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN)  :: weights !! Barycentric weights
      REAL(KIND=RP), DIMENSION(0:N), INTENT(INOUT) :: p
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER       :: j
      LOGICAL       :: xMatchesNode
      REAL(KIND=RP) :: d, t
!

!
!     -------------------------------------
!     See if the evaluation point is a node
!     -------------------------------------
!
      xMatchesNode = .false.
      DO j = 0, N 
         p(j) = 0.0_RP
         IF( AlmostEqual( x, nodes(j) ) )     THEN
            p(j) = 1.0_RP
            xMatchesNode = .true.
         END IF
      END DO
      IF( xMatchesNode )     RETURN
!
!     ------------------------------
!     Evaluation point is not a node
!     ------------------------------
!
      d = 0.0_RP
      DO j = 0, N 
         t = weights(j)/( x - nodes(j) )
         p(j) = t
         d = d + t
      END DO
      DO j = 0, N 
         p(j) = p(j)/d
      END DO
      
   END SUBROUTINE LagrangeInterpolatingPolynomialBarycentric

! /////////////////////////////////////////////////////////////////////
!
!---------------------------------------------------------------------
!!    Compute at x the derivative of the lagrange polynomial L_j(x) of
!!    degree N whose zeros are given by the nodes(i)
!---------------------------------------------------------------------
!
      pure REAL(KIND=RP) FUNCTION EvaluateLagrangePolyDerivative( j, x, N, nodes)
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER, INTENT(IN)                       :: j !! Which poly
      INTEGER, INTENT(IN)                       :: N !! Order
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN) :: nodes !! Nodes
      REAL(KIND=RP)                , INTENT(IN) :: x !! Eval Pt
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER       :: l, m
      REAL(KIND=RP) :: hp, poly
!                                                                       
      hp = 0.0_RP
      DO l = 0,N 
         IF(l == j)     CYCLE
         poly = 1.0_RP
         DO m = 0,N 
            IF (m == l)     CYCLE
            IF (m == j)     CYCLE 
            poly = poly*(x - nodes(m))/(nodes(j) - nodes(m))
         END DO
         hp = hp + poly/(nodes(j) - nodes(l)) 
      END DO
      EvaluateLagrangePolyDerivative = hp
!                                                                       
      END FUNCTION EvaluateLagrangePolyDerivative
!
!////////////////////////////////////////////////////////////////////////
!
!     ----------------------------------------------------------------
!!    Compute the barycentric weights for polynomial interpolation
!     ----------------------------------------------------------------
!
      SUBROUTINE BarycentricWeights( N, x, w )
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER :: N
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN)  :: x
      REAL(KIND=RP), DIMENSION(0:N), INTENT(OUT) :: w
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER :: j, k
!      
      w = 1.0_RP
      DO j = 1, N
         DO k = 0, j-1
            w(k) = w(k)*(x(k) - x(j))
            w(j) = w(j)*(x(j) - x(k))
         END DO
      END DO
      w = 1.0_RP/w

      END SUBROUTINE BarycentricWeights
!
!     ////////////////////////////////////////////////////////////////
!
!     ------------------------------------------------------------------
!!    Compute the value of the interpolant using the barycentric formula
!     ------------------------------------------------------------------
!
      REAL(KIND=RP) FUNCTION LagrangeInterpolation( x, N, nodes, values, weights)
      use Utilities
!
!     ---------
!     Arguments
!     ---------
!
      REAL(KIND=RP)                 :: x
      INTEGER                       :: N
      REAL(KIND=RP), DIMENSION(0:N) :: nodes
      REAL(KIND=RP), DIMENSION(0:N) :: values
      REAL(KIND=RP), DIMENSION(0:N) :: weights
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER       :: j
      REAL(KIND=RP) :: t, numerator, denominator
      
      numerator   = 0.0_RP
      denominator = 0.0_RP
      DO j = 0, N
         IF( AlmostEqual( x, nodes(j) ) )    THEN
            LagrangeInterpolation = values(j)
            RETURN 
         END IF 
         t = weights(j)/( x - nodes(j) )
         numerator = numerator + t*values(j)
         denominator = denominator + t
      END DO
      LagrangeInterpolation = numerator/denominator

      END FUNCTION LagrangeInterpolation
!
!     ////////////////////////////////////////////////////////////////
!
!     ------------------------------------------------------------------
!!    Compute the value of the interpolant using the barycentric formula
!     ------------------------------------------------------------------
!
      REAL(KIND=RP) FUNCTION LagrangeInterpolantDerivative( x, N, nodes, values, weights)
      use Utilities
!
!     ---------
!     Arguments
!     ---------
!
      REAL(KIND=RP)                 :: x
      INTEGER                       :: N
      REAL(KIND=RP), DIMENSION(0:N) :: nodes
      REAL(KIND=RP), DIMENSION(0:N) :: values
      REAL(KIND=RP), DIMENSION(0:N) :: weights
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER       :: j, i
      REAL(KIND=RP) :: t, numerator, denominator
      REAL(KIND=RP) :: p
      LOGICAL       :: atNode
      

!
!     --------------------------
!     See if the point is a node
!     --------------------------
!
      atNode = .FALSE.
      numerator   = 0.0_RP
      DO j = 0, N 
         IF( AlmostEqual( x, nodes(j) ) )    THEN
            atNode      = .TRUE.
            p           = values(j)
            denominator = -weights(j)
            i           = j
            EXIT 
         END IF
      END DO
      
      IF ( atNode )     THEN
         DO j = 0, N
            IF( j == i )    CYCLE
            numerator = numerator + weights(j)*(p - values(j))/( x - nodes(j) )
         END DO
      ELSE
         p = LagrangeInterpolation( x, N, nodes, values, weights)
         denominator = 0.0_RP
         DO j = 0, N
            t = weights(j)/( x - nodes(j) )
            numerator = numerator + t*(p - values(j))/( x - nodes(j) )
            denominator = denominator + t
         END DO
      END IF
      LagrangeInterpolantDerivative = numerator/denominator

      END FUNCTION LagrangeInterpolantDerivative
!
!     ////////////////////////////////////////////////////////////////
!
!     ------------------------------------------------------------------
!!    Compute the matrix T that transforms between the old set of nodes
!!    to the new set.
!!          Fi = Tij Fj -> T = Tij
!
!           -> N: old nodes size
!           -> M: new nodes size
!     ------------------------------------------------------------------
!
      SUBROUTINE PolynomialInterpolationMatrix( N, M, oldNodes, weights, newNodes, T)
      use Utilities
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER                      , INTENT(IN)  :: N, M
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN)  :: oldNodes
      REAL(KIND=RP), DIMENSION(0:M), INTENT(IN)  :: newNodes
      REAL(KIND=RP), DIMENSION(0:N), INTENT(IN)  :: weights
      
      REAL(KIND=RP), DIMENSION(0:M,0:N), INTENT(OUT) :: T
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER           :: j,k
      REAL(KIND=RP)     :: s, tmp
      LOGICAL           :: rowHasMatch
     
      DO k = 0,M
      
         rowHasMatch = .FALSE.
         DO j = 0,N
            T(k,j) = 0.0_RP
            IF( AlmostEqual(newNodes(k),oldNodes(j)) ) THEN
               rowHasMatch = .TRUE.
               T(k,j) = 1.0_RP
            END IF
         END DO 
         
         IF( .NOT.rowHasMatch )     THEN
            s = 0.0_RP
            DO j = 0,N
               tmp    = weights(j)/( newNodes(k) - oldNodes(j) )
               T(k,j) = tmp
               s      = s + tmp
            END DO
            DO j = 0, N 
               T(k,j) = T(k,j)/s
            END DO
         END IF
      END DO

      END SUBROUTINE PolynomialInterpolationMatrix
!
!////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE InterpolateToNewPoints( N, M, T, f, fInterp )
!
!-------------------------------------------------------------------
!!    Use matrix Multiplication to interpolate between two sets of
!!    nodes.
!-------------------------------------------------------------------
!
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER                          , INTENT(IN)  :: N, M
      REAL(KIND=RP), DIMENSION(0:M,0:N), INTENT(IN)  :: T
      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(IN)  :: f
      REAL(KIND=RP), DIMENSION(0:M)    , INTENT(OUT) :: fInterp
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER       :: i,j
      REAL(KIND=RP) :: tmp
      
      DO i = 0, M
         tmp = 0.0_RP
         DO j = 0, N
            tmp = tmp + T(i,j)*f(j)
         END DO 
         fInterp(i) = tmp
      END DO 
      
      END SUBROUTINE InterpolateToNewPoints
!
!    /////////////////////////////////////////////////////////////////
!
!     ----------------------------------------------------------------
!!    Compute the derivative matrix.
!!    D(i,j) = \prime \ell_j(x_i)
!     ----------------------------------------------------------------
!
      SUBROUTINE PolynomialDerivativeMatrix( N, nodes, D )
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER                           , INTENT(IN)  :: N
      REAL(KIND=RP), DIMENSION(0:N)     , INTENT(IN)  :: nodes
      REAL(KIND=RP), DIMENSION(0:N, 0:N), INTENT(OUT) :: D
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER                        :: i, j
      REAL(KIND=RP), DIMENSION(0:N)  :: baryWeights
!      
      CALL BarycentricWeights( N, nodes, baryWeights )
      
      DO i = 0, N
         D(i,i) = 0.0_RP
         DO j = 0, N
            IF( j /= i )     THEN
               D(i,j) = baryWeights(j)/( baryWeights(i)*(nodes(i) - nodes(j)) )
               D(i,i) = D(i,i) - D(i,j)
            END IF
         END DO
      END DO

      END SUBROUTINE PolynomialDerivativeMatrix
!
!    /////////////////////////////////////////////////////////////////
!
!     ----------------------------------------------------------------
!!    Compute the m^{th} derivative matrix.
!     ----------------------------------------------------------------
!
      SUBROUTINE mthPolynomialDerivativeMatrix( m, N, nodes, D )
!
!     ---------
!     Arguments
!     ---------
!
      INTEGER                           , INTENT(IN)  :: m
      INTEGER                           , INTENT(IN)  :: N
      REAL(KIND=RP), DIMENSION(0:N)     , INTENT(IN)  :: nodes
      REAL(KIND=RP), DIMENSION(0:N, 0:N), INTENT(OUT) :: D
!
!     ---------------
!     Local Variables
!     ---------------
!
      INTEGER                            :: i, j, l
      REAL(KIND=RP), DIMENSION(0:N)      :: baryWeights
      REAL(KIND=RP), DIMENSION(0:N, 0:N) :: DOld
!      
      CALL BarycentricWeights( N, nodes, baryWeights )
      CALL PolynomialDerivativeMatrix( N, nodes, DOld )
      
      DO l = 2, m
         DO i = 0, N
            D(i,i) = 0.0_RP
            DO j = 0, N
               IF( j /= i )     THEN
                  D(i,j) = l*(baryWeights(j)*DOld(i,i)/baryWeights(i) - DOld(j,i))/(nodes(i) - nodes(j))
                  D(i,i) = D(i,i) - D(i,j)
               END IF
            END DO
         END DO
         DOld = D
      END DO

      END SUBROUTINE mthPolynomialDerivativeMatrix
!
!////////////////////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE PolyDirectMatrixMultiplyDeriv( f, fDeriv, D, N )
      IMPLICIT NONE 
!
!     Compute the derivative approximation by simple matrix multiplication
!     This routine assumes that the matrix has been trasposed for faster
!     inner loop access.
!
!     ----------
!     Arguments:
!     ----------
!
      INTEGER                          , INTENT(IN)  :: N
      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(IN)  :: f
      REAL(KIND=RP), DIMENSION(0:N,0:N), INTENT(IN)  :: D

      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(OUT) :: fDeriv
!
!     ----------------
!     Local Variables:
!     ----------------
!
      INTEGER       :: i, j
      REAL(KIND=RP) :: t
      
      DO i = 0, N
         t = 0.0_RP
         DO j = 0, N
            t = t + D(j,i)*f(j)
         END DO
         fDeriv(i) = t
      END DO
      
      END SUBROUTINE PolyDirectMatrixMultiplyDeriv
!////////////////////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE MatrixMultiplyDeriv( f, fDeriv, D, N, transp )
!
!     Compute the derivative approximation by simple matrix multiplication
!     This routine assumes that the matrix has been trasposed for faster
!     inner loop access.
!
!     ----------
!     Arguments:
!     ----------
!
      INTEGER                          , INTENT(IN)  :: N
      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(IN)  :: f
      REAL(KIND=RP), DIMENSION(0:N,0:N), INTENT(IN)  :: D
      INTEGER                          , INTENT(IN)  :: transp

      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(OUT) :: fDeriv
!
!     ----------------
!     Local Variables:
!     ----------------
!
      INTEGER       :: i, j
      REAL(KIND=RP) :: t
      
      SELECT CASE ( transp )
      
         CASE( MXV_DIRECT )
             DO i = 0, N
               t = 0.0_RP
               DO j = 0, N
                  t = t + D(j,i)*f(j)
               END DO
               fDeriv(i) = t
            END DO
        
         CASE( MXV_TRANSPOSE )
             DO i = 0, N
               t = 0.0_RP
               DO j = 0, N
                  t = t + D(i,j)*f(j)
               END DO
               fDeriv(i) = t
            END DO
         
         CASE DEFAULT
      END SELECT
      
      END SUBROUTINE MatrixMultiplyDeriv
!
!////////////////////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE EOMatrixDerivative( u, uDeriv, D, N )
      IMPLICIT NONE 
!
!     Compute the matrix derivative using the even-odd decomposition    
!     e = even terms                                                    
!     ep = even derivative                                              
!     o = odd terms                                                     
!     op = odd derivative
!
      INTEGER                          , INTENT(IN)  :: N
      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(IN)  :: u
      REAL(KIND=RP), DIMENSION(0:N,0:N), INTENT(IN)  :: D
      
      REAL(KIND=RP), DIMENSION(0:N)    , INTENT(OUT) :: uDeriv

      REAL(KIND=RP), DIMENSION(0:N) :: e, o, ep, op
      REAL(KIND=RP)                 :: sume, sumo
      INTEGER                       :: M, nHalf, I, J
!
!     ----------------------------
!     Compute even and odd vectors                                      
!     ----------------------------
!
      M = (N+1)/2
      DO  j = 0,M
         e(j) = 0.5*(u(j) + u(n-j)) 
         o(j) = 0.5*(u(j) - u(n-j)) 
      END DO
!
!     -------------------------------------
!     Compute even and odd derivative terms                             
!     -------------------------------------
!
      DO i = 0, M-1
         sume = 0.0 
         sumo = 0.0 
         DO j = 0, M-1
            sume = sume + (D(j,i) + D(n-j,i))*e(j) 
            sumo = sumo + (D(j,i) - D(n-j,i))*o(j) 
         END DO
         ep(i) = sume 
         op(i) = sumo
      END DO
!
!     --------------------------------
!     Add in middle term if n+1 is odd                                   
!     --------------------------------
!
      nHalf = (n+1)/2
      IF(2*nHalf /= n+1)     THEN 
         DO i = 0, M-1 
            ep(i) = ep(i) + D(M,i)*e(M) 
         END DO
         ep(M) = 0.0 
         i = nHalf 
         sumo = 0.0 
         DO j = 0,M-1 
            sumo = sumo + (D(j,M) - D(n-j,M))*o(j) 
         END DO
         op(i) = sumo 
      END IF 
!
!     --------------------------
!     Construct full derivative                                         
!     --------------------------
!
      DO j = 0,M-1
         uDeriv(j)   = ( ep(j) + op(j)) 
         uDeriv(n-j) = (-ep(j) + op(j)) 
      END DO

      IF(2*nHalf /= n+1)     THEN 
         uDeriv(M) = (ep(M) + op(M))
      END IF 
!
      END SUBROUTINE EOMatrixDerivative                                           
!
!  **********     
   END MODULE InterpolationAndDerivatives
!  **********     
