open import Level renaming (zero to lzero; suc to lsuc) hiding (Lift)
open import Relation.Binary using (DecSetoid)

module DOTOmega.Typing {ℓ}
    (TypeL : DecSetoid lzero ℓ)
    (TermL : DecSetoid lzero ℓ)
  where

open import Data.List using (List; []; _∷_; map)

open import Data.Var

open import DOTOmega.Syntax TypeL TermL

open import Data.Context

data VarFact : Set where
  Kd : Kind → VarFact              -- Type variable kind assignment
  Ty : Type → VarFact              -- Term variable type assignment
  Alias : Type → Kind → VarFact    -- Type variable alias

liftVarFact : (Var → Var) → VarFact → VarFact
liftVarFact f (Kd k) = Kd (liftKind f k)
liftVarFact f (Ty τ) = Ty (liftType f τ)
liftVarFact f (Alias τ k) = Alias (liftType f τ) (liftKind f k)

instance
  VarFactLift : Lift VarFact
  VarFactLift = record {lift = liftVarFact}

Context = Ctx VarFact

infix 4 _ctx
infix 4 _⊢_kd
infix 4 _⊢ty_∈_
infix 4 _⊢kd_≤_ _⊢ty_≤_∈_
infix 4 _⊢ty_==_∈_

infix 4 _⊢tm_∈_
infix 4 _⊢defn_∈_ _⊢defns_∈_

mutual
  data _ctx : Context → Set where
    c-empty : [] ctx
    c-cons-kd : ∀{Γ x k} → Γ ctx → Γ ⊢ k kd → Γ & x ~ Kd k ctx
    c-cons-ty : ∀{Γ x τ k} → Γ ctx → Γ ⊢ty τ ∈ k → Γ & x ~ Ty τ ctx
    c-cons-alias : ∀{Γ x τ k} → Γ ctx → Γ ⊢ty τ ∈ k → Γ & x ~ Alias τ k ctx

  data _⊢_kd (Γ : Context) : Kind → Set where
    wf-intv : ∀{A B} → Γ ⊢ty A ∈ ✶ → Γ ⊢ty B ∈ ✶ → Γ ⊢ A ∙∙ B kd
    wf-darr : ∀{x J K} →
      Γ ⊢ J kd →
      Γ & x ~ Kd J ⊢ (openKind x K) kd →
      Γ ⊢ ℿ J K kd

  data _⊢ty_∈_ (Γ : Context) : Type → Kind → Set where
    k-var : ∀{name k} → Γ ctx → Γ [ name ]⊢> Kd k → Γ ⊢ty `(Free name) ∈ k
    k-alias : ∀{name τ k} →
      Γ ctx →
      Γ [ name ]⊢> Alias τ k →
      Γ ⊢ty `(Free name) ∈ k
    k-sing : ∀{A B C} →
      Γ ⊢ty A ∈ B ∙∙ C →
      Γ ⊢ty A ∈ A ∙∙ A
    k-arr : ∀{x A B} →
      Γ ⊢ty A ∈ ✶ →
      Γ & x ~ Ty A ⊢ty openType x B ∈ ✶ →
      Γ ⊢ty ℿ A B ∈ ✶
    k-abs : ∀{x J K A} →
      Γ ⊢ J kd →
      Γ & x ~ Kd J ⊢ty openType x A ∈ openKind x K →
      Γ ⊢ty ƛ J A ∈ ℿ J K
    k-app : ∀{J K x f z} →
      Γ ⊢ty ` f ∈ ℿ J K →
      Γ ⊢ty ` z ∈ J →
      Γ & x ~ Kd J ⊢ openKind x K kd →
      Γ ⊢ bindKind z K kd →
      Γ ⊢ty f ⊡ z ∈ bindKind z K
    k-intersect : ∀{τ₁ τ₂ A B} →
      Γ ⊢ty τ₁ ∈ A ∙∙ B →
      Γ ⊢ty τ₂ ∈ A ∙∙ B →
      Γ ⊢ty τ₁ ∧ τ₂ ∈ A ∙∙ B
    k-sub : ∀{J K A} →
      Γ ⊢ty A ∈ J → Γ ⊢kd J ≤ K →
      Γ ⊢ty A ∈ K
    k-field : ∀{ℓ τ A B} →
      Γ ⊢ty τ ∈ A ∙∙ B →
      Γ ⊢ty [ val ℓ ∶ τ ] ∈ ✶
    k-typ : ∀{A k} →
      Γ ⊢ k kd →
      Γ ⊢ty [ typ A ∶ k ] ∈ ✶

  data _⊢kd_≤_ (Γ : Context) : Kind → Kind → Set where
    sk-intv : ∀{A₁ A₂ B₁ B₂} →
      Γ ⊢ty A₂ ≤ A₁ ∈ ✶ →
      Γ ⊢ty B₁ ≤ B₂ ∈ ✶ →
      Γ ⊢kd A₁ ∙∙ B₁ ≤ A₂ ∙∙ B₂
    sk-darr : ∀{x J₁ J₂ K₁ K₂} →
      Γ ⊢ ℿ J₁ K₁ kd →
      Γ ⊢kd J₂ ≤ J₁ →
      Γ & x ~ Kd J₂ ⊢kd openKind x K₁ ≤ openKind x K₂ →
      Γ ⊢kd ℿ J₁ K₁ ≤ ℿ J₂ K₂

  data _⊢ty_≤_∈_ (Γ : Context) : Type → Type → Kind → Set where
    st-refl : ∀{K A} → Γ ⊢ty A ∈ K → Γ ⊢ty A ≤ A ∈ K
    st-trans : ∀{K A B C} →
      Γ ⊢ty A ≤ B ∈ K →
      Γ ⊢ty B ≤ C ∈ K →
      Γ ⊢ty A ≤ C ∈ K
    st-top : ∀{A B C} → Γ ⊢ty A ∈ B ∙∙ C → Γ ⊢ty A ≤ ⊤ ∈ ✶
    st-bot : ∀{A B C} → Γ ⊢ty A ∈ B ∙∙ C → Γ ⊢ty ⊥ ≤ A ∈ ✶
    st-alias₁ : ∀{x τ k} → Γ [ x ]⊢> Alias τ k → Γ ⊢ty `(Free x) ≤ τ ∈ k
    st-alias₂ : ∀{x τ k} → Γ [ x ]⊢> Alias τ k → Γ ⊢ty τ ≤ `(Free x) ∈ k
    st-and-l₁ : ∀{τ₁ τ₂ K} → Γ ⊢ty τ₁ ∧ τ₂ ∈ K → Γ ⊢ty τ₁ ∧ τ₂ ≤ τ₁ ∈ K
    st-and-l₂ : ∀{τ₁ τ₂ K} → Γ ⊢ty τ₁ ∧ τ₂ ∈ K → Γ ⊢ty τ₁ ∧ τ₂ ≤ τ₂ ∈ K
    st-and₂ : ∀{ρ τ₁ τ₂ K} →
      Γ ⊢ty ρ ≤ τ₁ ∈ K → Γ ⊢ty ρ ≤ τ₂ ∈ K →
      Γ ⊢ty ρ ≤ τ₁ ∧ τ₂ ∈ K
    st-field : ∀{ℓ τ₁ τ₂ k} →
      Γ ⊢ty τ₁ ≤ τ₂ ∈ k →
      Γ ⊢ty [ val ℓ ∶ τ₁ ] ≤ [ val ℓ ∶ τ₂ ] ∈ ✶
    st-typ : ∀{A k₁ k₂} →
      Γ ⊢kd k₁ ≤ k₂ →
      Γ ⊢ty [ typ A ∶ k₁ ] ≤ [ typ A ∶ k₂ ] ∈ ✶

  -- Type equality
  data _⊢ty_==_∈_ (Γ : Context) : Type → Type → Kind → Set where
    st-antisym : ∀{K A B} →
      Γ ⊢ty A ≤ B ∈ K → Γ ⊢ty B ≤ A ∈ K → Γ ⊢ty A == B ∈ K

  data _⊢tm_∈_ (Γ : Ctx VarFact) : Term → Type → Set where
    ty-var : ∀{name τ} → Γ [ name ]⊢> Ty τ → Γ ⊢tm `(Free name) ∈ τ
    ty-ℿ-intro : ∀{x τ ρ e} →
      Γ & x ~ Ty τ ⊢tm openTerm x e ∈ openType x ρ →
      Γ ⊢tm V(ƛ τ e) ∈ ℿ τ ρ
    ty-ℿ-elim : ∀{x z τ ρ} →
      Γ ⊢tm ` x ∈ ℿ τ ρ → Γ ⊢tm ` z ∈ τ →
      Γ ⊢tm x ⊡ z ∈ bindType z ρ
    ty-new-intro : ∀{τ x ds} →
      Γ & x ~ Ty (openType x τ) ⊢defns (map (openDefn x) ds) ∈ (openType x τ) →
      Γ ⊢tm V(new τ ds) ∈ μ τ
    ty-new-elim : ∀{x ℓ τ} →
      Γ ⊢tm ` x ∈ [ val ℓ ∶ τ ] →
      Γ ⊢tm x ∙ ℓ ∈ τ
    ty-let : ∀{e₁ e₂ x τ ρ} →
      Γ ⊢tm e₁ ∈ τ →
      Γ & x ~ Ty τ ⊢tm (openTerm x e₂) ∈ ρ →
      Γ ⊢tm (let' e₁ in' e₂) ∈ ρ
    ty-rec-intro : ∀{x τ} →
      Γ ⊢tm ` x ∈ bindType x τ →
      Γ ⊢tm ` x ∈ μ τ
    ty-rec-elim : ∀{x τ} →
      Γ ⊢tm ` x ∈ μ τ →
      Γ ⊢tm ` x ∈ bindType x τ
    ty-and-intro : ∀{x τ₁ τ₂} →
      Γ ⊢tm ` x ∈ τ₁ → Γ ⊢tm ` x ∈ τ₂ →
      Γ ⊢tm ` x ∈ τ₁ ∧ τ₂
    ty-lettype : ∀{τ e k x ρ} →
      Γ ⊢ty τ ∈ k →
      Γ & x ~ Alias τ k ⊢tm e ∈ ρ →
      Γ ⊢tm lettype τ in' e ∈ ρ
    ty-sub : ∀{e τ₁ τ₂} →
      Γ ⊢tm e ∈ τ₁ → Γ ⊢ty τ₁ ≤ τ₂ ∈ ✶ →
      Γ ⊢tm e ∈ τ₂

  -- Definition typing
  data _⊢defn_∈_ (Γ : Ctx VarFact) : Defn → Decl → Set where
    ty-defn-type : ∀{A k τ} → Γ ⊢ty τ ∈ k → Γ ⊢defn (typ A =' τ) ∈ typ A ∶ k
    ty-defn-term : ∀{ℓ e τ} →
      Γ ⊢tm e ∈ τ →
      Γ ⊢defn (val ℓ =' e) ∈ val ℓ ∶ τ

  data _⊢defns_∈_ (Γ : Ctx VarFact) : List Defn → Type → Set where
    ty-defns-one : ∀{d D} →
      Γ ⊢defn d ∈ D →
      Γ ⊢defns (d ∷ []) ∈ [ D ]
    ty-defns-cons : ∀{d ds D τ} →
      Γ ⊢defns ds ∈ τ →
      Γ ⊢defn d ∈ D →
      d ∉ ds →
      Γ ⊢defns (d ∷ ds) ∈ τ ∧ [ D ]

-- Lemmas/derived rules

intv≤✶ : ∀{Γ A B τ₁ τ₂ τ₃ τ₄} →
  Γ ⊢ty A ∈ τ₁ ∙∙ τ₂ → Γ ⊢ty B ∈ τ₃ ∙∙ τ₄ → Γ ⊢kd A ∙∙ B ≤ ✶
intv≤✶ Γ⊢A∈∙∙ Γ⊢B∈∙∙ = sk-intv (st-bot Γ⊢A∈∙∙) (st-top Γ⊢B∈∙∙)
