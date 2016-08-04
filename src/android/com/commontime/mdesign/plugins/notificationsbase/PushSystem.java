package com.commontime.mdesign.plugins.notificationsbase;

public abstract class PushSystem implements PushSystemInterface {

	private PushEngine engine;

	public enum State {
		idle, connecting, connected, disconnecting, reconnecting, unconfigured, active
	}

	protected PushEngine pushEngine;

	public PushSystem(PushEngine engine) {
		pushEngine = engine;
	}

	protected PushSystemObserver observer;

	public void setObserver(PushSystemObserver observer) {
		this.observer = observer;
	}

}
