#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState ) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod counter_contract {
    use starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        value: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }


    #[abi(embed_v0)]
    impl ICounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increase_counter(ref self: ContractState) {
            // Protect the function so only the owner can call it
            self.ownable.assert_only_owner();
            // Check if the kill switch is active before increasing the counter
            assert!(!IKillSwitchDispatcher { contract_address: self.kill_switch.read() }.is_active(), "Kill Switch is active");

            self.counter.write(self.counter.read() + 1);
            self.emit(CounterIncreased { value: self.counter.read() });

        }
    }
}