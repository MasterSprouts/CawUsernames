# Stake Pool Rewards

As mentioned in the spec, many actions taken by a user will involve redistributing some funds as rewards
to "all other stakers". To accomplish this, an algorithm has been developed which works as follows:


Assume `n` number of users (denoted as <code>u<sub>1</sub>, u<sub>2</sub>, ... u<sub>n</sub></code>) have deposited a total amount of CAW denoted as `totalDepositedCaw`
When an arbitrary user, <code>u<sub>i</sub></code>, removes `X` caw from their balance and distributes this amount as rewards to all other users,
the amount added to the account of any arbitrary user (<code>u<sub>j</sub></code>, where `j ≠ i`) will be `X` multiplied by <code>percentOwnership(u<sub>j</sub>)</code>,
where <code>percentOwnership(u<sub>j</sub>)</code> is the ratio of the balance of <code>u<sub>j</sub></code> to the total amount of CAW which has been deposited by all users aside from <code>u<sub>i</sub></code>. 


<pre><code>percentOwnership(u<sub>j</sub>) = balanceOf(u<sub>j</sub>) / (totalDepositedCaw - balanceOf(u<sub>i</sub>))
</code></pre>


The `balanceAfterReward` of <code>u<sub>j</sub></code> can be denoted as follows:

<pre><code>balanceAfterReward(u<sub>j</sub>) = balanceOf(u<sub>j</sub>) + X * percentOwnership(u<sub>j</sub>)
</code></pre>


i.e.

<pre><code>balanceAfterReward(u<sub>j</sub>) = balanceOf(u<sub>j</sub>) + X * balanceOf(u<sub>j</sub>) / (totalDepositedCaw - balanceOf(u<sub>i</sub>))
</code></pre>


therefore

<pre><code>balanceAfterReward(u<sub>j</sub>) = balanceOf(u<sub>j</sub>) * (1 + X / (totalDepositedCaw - balanceOf(u<sub>i</sub>))
</code></pre>


if we refer to the multiplier of the balance before the rewards as `r`, where

<pre><code>r = (1 + X / (totalDepositedCaw - balanceOf(u<sub>i</sub>))
</code></pre>


then


<pre><code>balanceAfterReward(u<sub>j</sub>) = balanceOf(u<sub>j</sub>) * r
</code></pre>


Since each amount distributed as rewards can be different, we can denote each amount as <code>X<sub>n</sub></code>, and 


<pre><code>r<sub>n</sub> = (1 + X<sub>n</sub> / (totalDepositedCaw<sub>n</sub> - balance<sub>n</sub>(u<sub>i</sub>))
</code></pre>


and therefore


<pre><code>balanceOf<sub>(n+1)</sub>(u<sub>j</sub>) = balanceOf<sub>n</sub>(u<sub>j</sub>) * r<sub>n</sub>
...
balanceOf<sub>3</sub>(u<sub>j</sub>) = balanceOf<sub>2</sub>(u<sub>j</sub>) * r<sub>2</sub>
balanceOf<sub>2</sub>(u<sub>j</sub>) = balanceOf<sub>1</sub>(u<sub>j</sub>) * r<sub>1</sub>
balanceOf<sub>1</sub>(u<sub>j</sub>) = balanceOf<sub>0</sub>(u<sub>j</sub>) * r<sub>0</sub>
</code></pre>


and by substitution, we can compute <code>balance<sub>3</sub></code> as:


<pre><code>balanceOf<sub>3</sub>(u<sub>j</sub>) = balanceOf<sub>2</sub>(u<sub>j</sub>) * r<sub>2</sub>
balanceOf<sub>3</sub>(u<sub>j</sub>) = balanceOf<sub>1</sub>(u<sub>j</sub>) * r<sub>1</sub> * r<sub>2</sub>
balanceOf<sub>3</sub>(u<sub>j</sub>) = balanceOf<sub>0</sub>(u<sub>j</sub>) * r<sub>0</sub> * r<sub>1</sub> * r<sub>2</sub>
</code></pre>


To compute the current value of any user at any time,
we just need to multiply it's initial balance by the product of all <code>r<sub>0</sub>...r<sub>n</sub></code>.
In the solidity contract, we are only ever interested in the current balance,
so we can persist a value, <code>rewardMultipler<sub>n</sub></code>, which is overwritten with with each reward distribution `n` as

<pre><code>rewardMultiplier<sub>n</sub> = rewardMultiplier<sub>(n-1)</sub> * r<sub>n</sub>
</code></pre>

which is equivalent to

<pre><code>rewardMultipler<sub>n</sub> = r<sub>0</sub> * r<sub>1</sub> * ... * r<sub>n</sub>
</code></pre>


and therefore, at any time

<pre><code>balanceOf<sub>n</sub>(u<sub>j</sub>) = balanceOf<sub>0</sub>(u<sub>j</sub>) * rewardMultipler<sub>n</sub>
</code></pre>

--
    
The one other piece of this algorithm that needs to be considered is the balance of <code>u<sub>i</sub></code>, 
after <code>u<sub>i</sub></code> distributes `X` from it's balance, it should receive no part of `X`, and must be
overwritten as it's pre-distribution balance minus `X`. Since the current balance of each <code>u<sub>n</sub></code>
is computed by multiplying `rewardMultipler`, we must overwrite the initial balance of <code>u<sub>i</sub></code>
to be in terms of <code>rewardMultipler<sub>n</sub></code>. Namely,


<pre><code>balanceOf<sub>0</sub>(u<sub>i</sub>) = (balanceOf<sub>n-1</sub>(u<sub>i</sub>) - X<sub>n</sub>) / rewardMultipler<sub>n</sub>
</code></pre>


Since the spec requires several transactions to move funds between users while simultaneously redistributing
rewards to all other stakers, the contract uses this process of overwriting <code>balanceOf<sub>0</sub></code>
in terms of <code>rewardMultipler<sub>n</sub></code> anytime a user receives, spends, deposits, or withdraws
any CAW from their balance.



QED



...

...

(p.s. I dedicate this proof to my grlfren, who not only endured me writing it, but also helped)


