{-# LANGUAGE RankNTypes #-}

import Control.Applicative

-- How can we pull out an element from a structure? One approach is zippers.

data PairContext a b = InFst b | InSnd a

data PairZipper a b c = PairZipper c (PairContext a b)

lookFstPZ :: (a,b) -> PairZipper a b a
lookFstPZ (a,b) = PairZipper a (InFst b)

unzipFstPZ :: PairZipper a b a -> (a,b)
unzipFstPZ (PairZipper a (InFst b)) = (a,b)

lookSndPZ :: (a,b) -> PairZipper a b b
lookSndPZ (a,b) = PairZipper b (InSnd a)

unzipSndPZ :: PairZipper a b b -> (a,b)
unzipSndPZ (PairZipper b (InSnd a)) = (a,b)

viewPZ :: PairZipper a b c -> c
viewPZ (PairZipper c l) = c

overPZ :: (c -> c) -> PairZipper a b c -> PairZipper a b c
overPZ f (PairZipper c l) = PairZipper (f c) l

-- Question: how can we compose these so that we can lookFstPZ, then lookSndPZ, and have this be another kind of Zipper-like thing?
-- Answer: too hard, forget it.

data ListContext a = ListCtx [a] [a]

data ListZipper a = ListZipper a (ListContext a)

lookHeadLZ :: [a] -> ListZipper a
lookHeadLZ (a:as) = ListZipper a (ListCtx [] as)

unzipLZ :: ListZipper a -> [a]
unzipLZ (ListZipper a (ListCtx bfr aft)) = bfr ++ [a] ++ aft

viewLZ :: ListZipper a -> a
viewLZ (ListZipper a l) = a

overLZ :: (a -> a) -> ListZipper a -> ListZipper a
overLZ f (ListZipper a l) = ListZipper (f a) l

-- Question: how can we compose these? Again, too hard. Forget it!

data Tree a = Leaf a | Branch a (Tree a) (Tree a)

data TreeCtx a = Here | InLeft a (TreeCtx a) (Tree a) | InRight a (Tree a) (TreeCtx a)

data TreeZipper a = TreeZipper (Tree a) (TreeCtx a)

lookRootTZ :: Tree a -> TreeZipper a
lookRootTZ t = TreeZipper t Here

unzipTZ :: TreeZipper a -> Tree a
unzipTZ (TreeZipper t Here) = t
unzipTZ (TreeZipper l (InLeft a c r)) = unzipTZ (TreeZipper (Branch a l r) c)
unzipTZ (TreeZipper r (InRight a l c)) = unzipTZ (TreeZipper (Branch a l r) c)

viewTZ :: TreeZipper a -> a
viewTZ (TreeZipper (Leaf a) c) = a
viewTZ (TreeZipper (Branch a l r) c) = a

overTZ :: (a -> a) -> TreeZipper a -> TreeZipper a
overTZ f (TreeZipper (Leaf a) c) = TreeZipper (Leaf (f a)) c
overTZ f (TreeZipper (Branch a l r) c) = TreeZipper (Branch (f a) l r) c

-- Question: ... well you get the idea.

-- Why not just use...

data Focused s a = Focused { foc :: a, loc :: a -> s }

-- We can now be pretty generic:

unfocusF :: Focused s a -> s
unfocusF (Focused foc loc) = loc foc

type Focuser s a = s -> Focused s a

viewF :: Focuser s a -> s -> a
viewF l s = foc (l s)

overF :: Focuser s a -> (a -> a) -> s -> s
overF l f s = let Focused foc loc = l s
              in loc (f foc)

-- Let's also introduce a new function that makes life simpler:

setF :: Focuser s a -> a -> s -> s
setF l a s = overF l (const a) s

-- Let's look at our various zippers, but this time viewed as focused elements:

lookFstF :: Focuser (a,b) a
lookFstF (a,b) = Focused a (\a' -> (a,b))

lookSndF :: Focuser (a,b) b
lookSndF (a,b) = Focused b (\b' -> (a,b'))

lookHeadF :: Focuser [a] a
lookHeadF (a:as) = Focused a (\a' -> a:as)

lookRootF :: Focuser (Tree a) a
lookRootF (Leaf a) = Focused a Leaf
lookRootF (Branch a l r) = Focused a (\a' -> Branch a' l r)

-- We can now answer our question about how to compose:

(>-) :: Focuser a b -> Focuser b c -> Focuser a c
(l >- l') a = let Focused foc loc = l a
                  Focused foc' loc' = l' foc
              in Focused foc' (loc.loc')

-- This does exactly what you'd hope: lookFstF >- lookSndF :: Focuser ((a,b),c) b  is exactly
-- the gadget that looks at the first element of the outer pair, then at the second of that
-- same for, say, lists:  lookHeadF >- lookFstF :: Focuser [(a,b)] a  looks at the first
-- component of the head of a list of pairs. and so on generically.

-- But over has an unusual restriction: the action on the focused element can't change the
-- elements type. Sometimes that seems reasonable, like for a list which have to be homogeneously
-- typed, but other times it's an unnecessary constraint, such as for pairs. Why can't we, for
-- instance, focus on the first component of an (a,b) and then somehow act on it to produce
-- an (a',b)? We need to generalize focusing for this to work:

data Focused' t a b = Focused' { foc' :: a, loc' :: b -> t }

type Focuser' s t a b = s -> Focused' t a b

-- fortunately, that's _all_ we have to change. the rest is identical, other than types:

unfocusF' :: Focused' s a a -> s
unfocusF' (Focused' foc loc) = loc foc

viewF' :: Focuser' s t a b -> s -> a
viewF' l s = foc' (l s)

overF' :: Focuser' s t a b -> (a -> b) -> s -> t
overF' l f s = let Focused' foc loc = l s
               in loc (f foc)

setF' :: Focuser' s t a b -> b -> s -> t
setF' l b s = overF' l (const b) s

lookFstF' :: Focuser' (a,b) (a',b) a a'
lookFstF' (a,b) = Focused' a (\a' -> (a',b))

lookSndF' :: Focuser' (a,b) (a,b') b b'
lookSndF' (a,b) = Focused' b (\b' -> (a,b'))

lookHeadF' :: Focuser' [a] [a] a a
lookHeadF' (a:as) = Focused' a (\a' -> a:as)

lookRootF' :: Focuser' (Tree a) (Tree a) a a
lookRootF' (Leaf a) = Focused' a Leaf
lookRootF' (Branch a l r) = Focused' a (\a' -> Branch a' l r)

-- We can again compose:

(>--) :: Focuser' s t a b -> Focuser' a b u v -> Focuser' s t u v
(l >-- l') a = let Focused' foc loc = l a
                   Focused' foc' loc' = l' foc
               in Focused' foc' (loc.loc')

-- So we have some nice examples now, for instance:  setF' lookFstF' 3 ("a","b") == (3,"b")

-- It would be nice, however, if we could use lenses to traverse structures, not just
-- look at them or change them. But traverse has a funny type:
--   traverse :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)
-- This looks almost like the type of overF' l, for some l, but not quite. We have these
-- extra f's and t's in there. We can factor out the f's to make things closer:

type Traversal s t a b = forall f. Applicative f => (a -> f b) -> s -> f t

-- which lets us say that
--   traverse :: Traversable t => Traversal (t a) (t b) a b
-- This expands to the correct type, but we still need to somehow fit our Focuser's
-- into the mold of the definition of Traversal. Well, as it happens, our Focuser'
-- type is equivalent to the type

type Lens s t a b = forall f. Functor f => (a -> f b) -> s -> f t

type SimpleLens s a = Lens s s a a

-- which makes it rather easy to see what we need to do: replace Focuser' with Lens!

-- Getting the equivalent views requires some tricky thinking about the types, however.
-- The way we viewed the focused element before was to just focus and pull out the foc
-- field, but there is no foc field in Lens. So instead we have to somehow convince a Lens
-- that it can pull out an a from an s some other way. But we can take advantage of the
-- fact that a Lens is polymorphic on its functor -- that tells us that the lens must
-- be constructed using only the functorial structure, nothing else, because it has to
-- work for all functors, not just one particular one. The Const functor gives us
-- exactly what we want. If we instantiate Lens with f = Const a, we get
--   (a -> Const a b) -> s -> Const a t
-- but Const a b can be seen as an a masquerading as a b. Same for Const a t. Any purely
-- functorially-defined actions on a Const a b will look to the type system like something
-- has happened, but the a contents will remain unaffected. That means that any Lens
-- will leave such a thing alone. We just need to provide our lense with a function
--   a -> Const a b
-- that can hide the a away. But that's just what the Const constructor does:

view :: Lens s t a b -> s -> a
view l s = getConst (l Const s)

-- It's good at this point to give an intuition about these Lenses, now that we have the
-- simplest way of interacting with them. The first argument to the Lens can be seen as
-- an action to perform on the a element that's embedded in the s structure. In the case of
-- view, the action is to masquerade the a element as a b, so that the loc-like behavior
-- of l, which is now just implicit in l, will smuggle the a up and out, where getConst
-- can reveal it as an a.

-- Similarly for over, we want f to be some useful functor, which happens to be Identity,
-- because a ~ Identity a in a trivial way, so
--   (a -> b) -> s -> t  ~  (a -> Identity b) -> s -> Identity t

data Identity a = Identity { getIdentity :: a }

instance Functor Identity where
  fmap f (Identity a) = Identity (f a)

over :: Lens s t a b -> (a -> b) -> s -> t
over l f s = getIdentity (l (Identity . f) s)

-- we can of course convert back and forth between Focuser's and Lenses.

lens :: Focuser' s t a b -> Lens s t a b
lens l f s = let Focused' foc loc = l s
             in fmap loc (f foc)

focuser :: Lens s t a b -> Focuser' s t a b
focuser l s = Focused' (view l s) (\b -> over l (const b) s)

-- That these are mutual inverses is relatively easy to show.

-- Here are our Focuser's again, this time as Lenses:

_1 :: Lens (a,b) (a',b) a a'
_1 f (a,b) = (\a' -> (a',b)) <$> f a

_2 :: Lens (a,b) (a,b') b b'
_2 f (a,b) = (\b' -> (a,b')) <$> f b

_head :: SimpleLens [a] a
_head f (a:as) = (\a' -> a:as) <$> f a

_root :: SimpleLens (Tree a) a
_root f (Leaf a) = Leaf <$> f a
_root f (Branch a l r) = (\a' -> Branch a' l r) <$> f a

-- Notice that this is more or less exactly how things would behave if we focused
-- with whichever focuser, used an action on the focus, and then unfocused. Except here,
-- the unfocus function application is not the normal application but is instead
-- functorial, using fmap in its infix form (<$>).
--
-- That means that we can compose lenses as functions with (.) instead of defining a custom
-- composition, and we get something rather sensible looking:
--   _head._1 :: SimpleLens [(a,b)] a
--   = \f ((a,b):ps) -> (\p' -> p':ps) <$> ((\a' -> (a',b)) <$> f a)
-- sometimes this is described as composing "backwards", but it really shouldn't be
-- seen like that. instead, you just need to think of lenses as things which turn
-- actions on parts into actions on wholes. so _1 doesn't "retrieve" the first component
-- of a pair, rather, it turns an action on the first component into an action on the whole
-- pair. same with _head -- it turns an action on the head element into an action on the
-- whole list. that means that if you compose two lenses, you're making an action on the whole
-- that runs an action on a part that runs an action on an even smaller part. That's just what
-- fmap does: it pushes actions down into structure. Lenses just happen to do that in a
-- very specific way, to a focused place, rather than in the usual "apply everywhere" way
-- that normal functor intuitions provide.
--
-- This schema also lets us produce lenses really easily. The general picture is
--   _l f m = (\a' -> [a'/a]m) <$> f a
-- where m is some pattern with variable a, and [a'/a]m is the pattern with all occurances
-- of a replaced by a', just so we don't get confused with the new bound variable.

_12 :: SimpleLens (a,b,c) (a,b)
_12 f (a,b,c) = (\(a',b') -> (a',b',c)) <$> f (a,b)
